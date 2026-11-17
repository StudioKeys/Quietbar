import JBLProtocol
import os

public typealias Sleeper = @Sendable (Duration) async throws -> Void

public actor HeadphoneSession {
    public static let wantsConnectionKey = "wantsConnection"
    private static let logger = Logger(subsystem: "dev.studiokeys.quietbar", category: "HeadphoneSession")

    public nonisolated let snapshots: AsyncStream<SessionSnapshot>
    private let continuation: AsyncStream<SessionSnapshot>.Continuation
    private let transport: any HeadphoneTransport
    private let replyTimeout: Duration
    private let sleep: Sleeper
    private let preferences: any PreferenceStore
    private let policy: ReconnectPolicy
    private let batteryInterval: Duration
    private var snapshot = SessionSnapshot.initial
    private var listeners: [Task<Void, Never>] = []
    private var linking: Task<Void, Never>?
    private var isLinking = false
    private var poller: Task<Void, Never>?
    private var waiters = ReplyWaiters()

    public var current: SessionSnapshot { snapshot }

    public init(
        transport: any HeadphoneTransport,
        replyTimeout: Duration = .seconds(3),
        sleep: @escaping Sleeper = { try await Task.sleep(for: $0) },
        preferences: any PreferenceStore = InMemoryPreferenceStore(),
        policy: ReconnectPolicy = .standard,
        batteryInterval: Duration = .seconds(300)
    ) {
        (snapshots, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(16))
        self.transport = transport
        self.replyTimeout = replyTimeout
        self.sleep = sleep
        self.preferences = preferences
        self.policy = policy
        self.batteryInterval = batteryInterval
    }

    public func start() async {
        startListening()
        guard wantsConnection else {
            publish(snapshot.with(status: .disconnectedByUser))
            return
        }
        await linkUp()
    }

    public func userConnect() async {
        preferences.set(true, forKey: Self.wantsConnectionKey)
        await linkUp()
    }

    public func userDisconnect() async {
        preferences.set(false, forKey: Self.wantsConnectionKey)
        linking?.cancel()
        stopPolling()
        await transport.disconnect()
        publish(snapshot.with(status: .disconnectedByUser))
    }

    public func refresh() async {
        for command in Command.refreshAll {
            await send(command)
        }
    }

    public func apply(_ command: Command) async throws(ApplyError) {
        guard snapshot.status == .connected else { throw .notConnected }
        do {
            try await confirmWithFollowUp(command)
            publish(snapshot.with(lastError: nil))
        } catch {
            publish(snapshot.with(lastError: error.message))
            throw error
        }
    }

    private func confirmWithFollowUp(_ command: Command) async throws(ApplyError) {
        do {
            try await confirm(command)
        } catch .timedOut {
            try await confirm(command.expectedReply.query)
        }
    }

    private func confirm(_ command: Command) async throws(ApplyError) {
        let ticket = waiters.expect(command.expectedReply)
        do {
            try await transport.send(command.frame)
        } catch {
            _ = waiters.expire(ticket)
            throw .writeFailed
        }
        guard await waitForReply(ticket) else { throw .timedOut }
    }

    private func waitForReply(_ ticket: ReplyWaiters.Ticket) async -> Bool {
        if waiters.consumeFulfilled(ticket) { return true }
        guard waiters.isPending(ticket) else { return false }
        let timeout = replyTimeout
        return await withCheckedContinuation { continuation in
            waiters.park(ticket, continuation)
            Task { [weak self] in
                try? await Task.sleep(for: timeout)
                await self?.expire(ticket)
            }
        }
    }

    private func expire(_ ticket: ReplyWaiters.Ticket) {
        waiters.expire(ticket)?.resume(returning: false)
    }

    private var wantsConnection: Bool {
        preferences.bool(forKey: Self.wantsConnectionKey) ?? true
    }

    private func linkUp() async {
        guard !isLinking, snapshot.status != .connected else { return }
        isLinking = true
        defer { isLinking = false }
        publish(snapshot.with(status: .searching))
        var failures = 0
        while wantsConnection, !Task.isCancelled {
            do {
                try await transport.connect()
                await didConnect()
                return
            } catch .bluetoothUnavailable(let issue) {
                publish(snapshot.with(status: .unavailable(issue)))
                return
            } catch {
                failures += 1
                guard await backOff(after: error, failures: failures) else { return }
            }
        }
    }

    private func backOff(after error: TransportError, failures: Int) async -> Bool {
        let delay = policy.delay(afterFailures: failures)
        Self.logger.notice("Connect failed (\(String(describing: error), privacy: .public)); retry in \(delay)")
        publish(snapshot.with(status: .retrying(after: delay, phoneHint: error == .connectFailed)))
        do {
            try await sleep(delay)
            return true
        } catch {
            return false
        }
    }

    private func didConnect() async {
        guard wantsConnection else {
            await transport.disconnect()
            return
        }
        publish(snapshot.with(status: .connected))
        await refresh()
        startPolling()
    }

    private func startPolling() {
        poller?.cancel()
        let sleep = sleep
        let interval = batteryInterval
        poller = Task { [weak self] in
            while !Task.isCancelled {
                guard (try? await sleep(interval)) != nil else { return }
                await self?.pollBattery()
            }
        }
    }

    private func stopPolling() {
        poller?.cancel()
        poller = nil
    }

    private func pollBattery() async {
        guard snapshot.status == .connected else { return }
        await send(.queryBattery)
    }

    private func handle(_ event: LinkEvent) {
        switch event {
        case .connected:
            return
        case .disconnected:
            stopPolling()
            guard wantsConnection, snapshot.status != .disconnectedByUser else { return }
            publish(snapshot.with(status: .searching))
            relink()
        case .bluetoothUnavailable(let issue):
            stopPolling()
            publish(snapshot.with(status: .unavailable(issue)))
        case .bluetoothReady:
            guard wantsConnection, snapshot.status != .connected else { return }
            relink()
        }
    }

    private func relink() {
        linking = Task { [weak self] in await self?.linkUp() }
    }

    private func send(_ command: Command) async {
        do {
            try await transport.send(command.frame)
        } catch {
            Self.logger.error("Send \(String(describing: command), privacy: .public) failed: \(error)")
        }
    }

    private func startListening() {
        guard listeners.isEmpty else { return }
        let incoming = transport.incoming
        let events = transport.events
        listeners = [
            Task { [weak self] in
                for await frame in incoming {
                    await self?.receive(frame)
                }
            },
            Task { [weak self] in
                for await event in events {
                    await self?.handle(event)
                }
            },
        ]
    }

    private func receive(_ frame: Frame) {
        let reply = Reply(frame: frame)
        let updated = snapshot.state.applying(reply)
        if updated != snapshot.state {
            publish(snapshot.with(state: updated))
        }
        guard let kind = reply.kind else { return }
        for continuation in waiters.deliver(kind) {
            continuation.resume(returning: true)
        }
    }

    private func publish(_ next: SessionSnapshot) {
        snapshot = next
        continuation.yield(next)
    }
}
