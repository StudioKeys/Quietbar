import JBLProtocol
import os

public typealias Sleeper = @Sendable (Duration) async throws -> Void

public actor HeadphoneSession {
    private static let logger = Logger(subsystem: "dev.studiokeys.quietbar", category: "HeadphoneSession")

    public nonisolated let snapshots: AsyncStream<SessionSnapshot>
    private let continuation: AsyncStream<SessionSnapshot>.Continuation
    private let transport: any HeadphoneTransport
    private let replyTimeout: Duration
    private let sleep: Sleeper
    private var snapshot = SessionSnapshot.initial
    private var listener: Task<Void, Never>?
    private var waiters = ReplyWaiters()

    public var current: SessionSnapshot { snapshot }

    public init(
        transport: any HeadphoneTransport,
        replyTimeout: Duration = .seconds(3),
        sleep: @escaping Sleeper = { try await Task.sleep(for: $0) }
    ) {
        (snapshots, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(16))
        self.transport = transport
        self.replyTimeout = replyTimeout
        self.sleep = sleep
    }

    public func start() async {
        startListening()
        await connect()
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

    private func connect() async {
        publish(snapshot.with(status: .searching))
        do {
            try await transport.connect()
            publish(snapshot.with(status: .connected))
            await refresh()
        } catch {
            Self.logger.error("Connect failed: \(String(describing: error), privacy: .public)")
            publish(snapshot.with(status: .retrying(after: .zero, phoneHint: true)))
        }
    }

    private func send(_ command: Command) async {
        do {
            try await transport.send(command.frame)
        } catch {
            Self.logger.error("Send \(String(describing: command), privacy: .public) failed: \(error)")
        }
    }

    private func startListening() {
        guard listener == nil else { return }
        let incoming = transport.incoming
        listener = Task { [weak self] in
            for await frame in incoming {
                await self?.receive(frame)
            }
        }
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
