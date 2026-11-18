import Foundation
import os

public actor DeviceSession {
    public static let wantsConnectionKey = "wantsConnection"
    private static let logger = Logger(subsystem: "dev.studiokeys.quietbar", category: "DeviceSession")

    public nonisolated let snapshots: AsyncStream<DeviceSnapshot>
    private let continuation: AsyncStream<DeviceSnapshot>.Continuation
    private let driver: any DeviceDriver
    private let transport: any DeviceTransport
    private let replyTimeout: Duration
    private let sleep: Sleeper
    private let preferences: any PreferenceStore
    private let policy: ReconnectPolicy
    private let batteryInterval: Duration
    private let watcher: (any ConnectionWatcher)?
    private let connectionPreferenceKey: String
    private var snapshot = DeviceSnapshot.initial
    private var listeners: [Task<Void, Never>] = []
    private var linking: Task<Void, Never>?
    private var isLinking = false
    private var linkGeneration = 0
    private var poller: Task<Void, Never>?
    private var waiters = ReplyWaiters<SettingID>()

    public var current: DeviceSnapshot { snapshot }

    public init(
        driver: any DeviceDriver,
        transport: any DeviceTransport,
        replyTimeout: Duration = .seconds(3),
        sleep: @escaping Sleeper = { try await Task.sleep(for: $0) },
        preferences: any PreferenceStore = InMemoryPreferenceStore(),
        policy: ReconnectPolicy = .standard,
        batteryInterval: Duration = .seconds(300),
        watcher: (any ConnectionWatcher)? = nil,
        connectionPreferenceKey: String = DeviceSession.wantsConnectionKey
    ) {
        (snapshots, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(16))
        self.driver = driver
        self.transport = transport
        self.replyTimeout = replyTimeout
        self.sleep = sleep
        self.preferences = preferences
        self.policy = policy
        self.batteryInterval = batteryInterval
        self.watcher = watcher
        self.connectionPreferenceKey = connectionPreferenceKey
    }

    public func start() async {
        startListening()
        guard wantsConnection else {
            publish(snapshot.with(status: .disconnectedByUser))
            return
        }
        await runLink()
    }

    public func userConnect() async {
        preferences.set(true, forKey: connectionPreferenceKey)
        await runLink()
    }

    public func userDisconnect() async {
        preferences.set(false, forKey: connectionPreferenceKey)
        linkGeneration += 1
        linking?.cancel()
        stopPolling()
        await transport.disconnect()
        publish(snapshot.with(status: .disconnectedByUser))
    }

    public func stop() async {
        linkGeneration += 1
        linking?.cancel()
        stopPolling()
        await transport.disconnect()
        publish(snapshot.with(status: .idle))
    }

    public func refresh() async {
        for request in driver.refreshRequests {
            await send(request)
        }
    }

    public func apply(_ change: SettingChange) async throws(ApplyError) {
        guard snapshot.status == .connected else { throw .notConnected }
        do throws(ApplyError) {
            guard let requests = driver.requests(for: change, current: snapshot.state) else {
                throw ApplyError.unsupported
            }
            if appliesWithReconnect(change.id) {
                try await sendAll(requests)
            } else {
                try await confirmWithFollowUp(requests, setting: change.id)
            }
            publish(snapshot.with(lastError: nil))
        } catch {
            Self.logger.notice(
                "\(change.id.rawValue, privacy: .public) not confirmed: \(error.message, privacy: .public)")
            publish(snapshot.with(lastError: error.message))
            throw error
        }
    }

    private func appliesWithReconnect(_ id: SettingID) -> Bool {
        driver.model.settings.first { $0.id == id }?.appliesWithReconnect ?? false
    }

    private func sendAll(_ requests: [Data]) async throws(ApplyError) {
        do {
            for request in requests {
                try await transport.send(request)
            }
        } catch {
            throw .writeFailed
        }
    }

    private func confirmWithFollowUp(_ requests: [Data], setting: SettingID) async throws(ApplyError) {
        do {
            try await confirm(requests, setting: setting)
        } catch .timedOut {
            guard let query = driver.confirmingRequest(for: setting) else { throw .timedOut }
            try await confirm([query], setting: setting)
        }
    }

    private func confirm(_ requests: [Data], setting: SettingID) async throws(ApplyError) {
        let ticket = waiters.expect(setting)
        do {
            for request in requests {
                try await transport.send(request)
            }
        } catch {
            _ = waiters.expire(ticket)
            throw .writeFailed
        }
        guard await waitForReply(ticket) else { throw .timedOut }
    }

    private func waitForReply(_ ticket: ReplyWaiters<SettingID>.Ticket) async -> Bool {
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

    private func expire(_ ticket: ReplyWaiters<SettingID>.Ticket) {
        waiters.expire(ticket)?.resume(returning: false)
    }

    private var wantsConnection: Bool {
        preferences.bool(forKey: connectionPreferenceKey) ?? true
    }

    private func runLink() async {
        linkGeneration += 1
        let generation = linkGeneration
        let previous = linking
        previous?.cancel()
        await previous?.value
        guard generation == linkGeneration, wantsConnection else { return }
        let link = Task { [weak self] in
            guard let self else { return }
            await establishLink()
        }
        linking = link
        await link.value
    }

    private func establishLink() async {
        isLinking = true
        defer { isLinking = false }
        guard await linkUp() else { return }
        guard !Task.isCancelled else {
            await transport.disconnect()
            return
        }
        await didConnect()
    }

    private func linkUp() async -> Bool {
        guard snapshot.status != .connected, wantsConnection else { return false }
        publish(snapshot.with(status: .searching))
        var failures = 0
        while wantsConnection, !Task.isCancelled {
            do {
                try await transport.connect()
                return true
            } catch .bluetoothUnavailable(let issue) {
                publish(snapshot.with(status: .unavailable(issue)))
                return false
            } catch {
                failures += 1
                guard failures < policy.maxAttempts else {
                    Self.logger.notice("Connect failed \(failures, privacy: .public) times; waiting")
                    publish(snapshot.with(status: .waiting))
                    return false
                }
                guard await backOff(after: error, failures: failures) else { return false }
            }
        }
        return false
    }

    private func backOff(after error: TransportError, failures: Int) async -> Bool {
        guard wantsConnection, !Task.isCancelled else { return false }
        let delay = policy.delay(afterFailures: failures)
        Self.logger.notice(
            "Connect failed (\(String(describing: error), privacy: .public)); retry in \(delay, privacy: .public)")
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
        guard snapshot.status == .connected else { return }
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
        guard snapshot.status == .connected, let query = driver.confirmingRequest(for: .battery) else { return }
        await send(query)
    }

    private func handle(_ event: LinkEvent) {
        switch event {
        case .connected:
            return
        case .disconnected:
            stopPolling()
            guard wantsConnection, snapshot.status != .disconnectedByUser else { return }
            publish(snapshot.with(status: .searching))
            Task { [weak self] in await self?.runLink() }
        case .bluetoothUnavailable(let issue):
            stopPolling()
            publish(snapshot.with(status: .unavailable(issue)))
        case .bluetoothReady:
            guard wantsConnection, snapshot.status != .connected, !isLinking else { return }
            Task { [weak self] in await self?.runLink() }
        }
    }

    private func send(_ request: Data) async {
        do {
            try await transport.send(request)
        } catch {
            Self.logger.error("Send failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func startListening() {
        guard listeners.isEmpty else { return }
        let incoming = transport.incoming
        let events = transport.events
        listeners = [
            Task { [weak self] in
                for await packet in incoming {
                    await self?.receive(packet)
                }
            },
            Task { [weak self] in
                for await event in events {
                    await self?.handle(event)
                }
            },
        ]
        if let connections = watcher?.connections {
            listeners.append(
                Task { [weak self] in
                    for await name in connections {
                        await self?.classicDeviceConnected(name)
                    }
                })
        }
    }

    private func classicDeviceConnected(_ name: String) {
        guard name.localizedCaseInsensitiveContains(driver.model.gatt.nameFragment), wantsConnection else { return }
        switch snapshot.status {
        case .idle, .connected, .searching, .disconnectedByUser, .unavailable:
            return
        case .retrying, .waiting:
            Self.logger.notice("\(name, privacy: .public) connected to the Mac; reconnecting")
            Task { [weak self] in await self?.runLink() }
        }
    }

    private func receive(_ packet: Data) {
        let updates = driver.updates(from: packet)
        let updated = snapshot.state.applying(updates)
        if updated != snapshot.state {
            publish(snapshot.with(state: updated))
        }
        for id in updates.map(\.settingID) {
            for continuation in waiters.deliver(id) {
                continuation.resume(returning: true)
            }
        }
    }

    private func publish(_ next: DeviceSnapshot) {
        snapshot = next
        continuation.yield(next)
    }
}

extension DeviceUpdate {
    fileprivate var settingID: SettingID {
        switch self {
        case .setting(let id, _): id
        case .battery: .battery
        }
    }
}
