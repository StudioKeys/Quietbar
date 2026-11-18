import Foundation
import os

public actor DeviceSession {
    public static let wantsConnectionKey = "wantsConnection"
    static let logger = Logger(subsystem: "dev.studiokeys.quietbar", category: "DeviceSession")

    public nonisolated let snapshots: AsyncStream<DeviceSnapshot>
    let continuation: AsyncStream<DeviceSnapshot>.Continuation
    let driver: any DeviceDriver
    let transport: any DeviceTransport
    let replyTimeout: Duration
    let sleep: Sleeper
    let preferences: any PreferenceStore
    let policy: ReconnectPolicy
    let batteryInterval: Duration
    let watcher: (any ConnectionWatcher)?
    let connectionPreferenceKey: String
    let identityPreferenceKey: String
    var memory: HeadphoneMemory
    var snapshot = DeviceSnapshot.initial
    var listeners: [Task<Void, Never>] = []
    var linking: Task<Void, Never>?
    var isLinking = false
    var linkGeneration = 0
    var isStopped = false
    var framer: any PacketFramer = PassthroughFramer()
    var handshakeState = DeviceState.empty
    var readyWaiter: CheckedContinuation<Bool, Never>?
    var readyToken = 0
    var hasRestoredIdentity = false
    var poller: Task<Void, Never>?
    var waiters = ReplyWaiters<SettingID>()

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
        deviceID: String? = nil
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
        self.connectionPreferenceKey = Self.connectionKey(for: deviceID)
        self.identityPreferenceKey = Self.identityKey(for: deviceID)
        let stored = preferences.string(forKey: Self.identityKey(for: deviceID)).flatMap(DeviceIdentity.decode)
        self.memory = HeadphoneMemory(identity: stored, nameFragment: driver.model.nameFragment)
    }

    public static func connectionKey(for deviceID: String?) -> String {
        deviceID.map { "\(wantsConnectionKey).\($0)" } ?? wantsConnectionKey
    }

    public static func identityKey(for deviceID: String?) -> String {
        deviceID.map { "identity.\($0)" } ?? "identity"
    }

    func restoreIdentity() async {
        guard !hasRestoredIdentity, let identity = memory.identity else { return }
        hasRestoredIdentity = true
        await transport.remember(identity)
        publish(snapshot.with(deviceName: identity.displayName))
    }

    func saveMemory() {
        guard let identity = memory.identity else { return }
        preferences.set(identity.encoded, forKey: identityPreferenceKey)
        publish(snapshot.with(deviceName: identity.displayName))
    }

    public func start() async {
        isStopped = false
        startListening()
        await restoreIdentity()
        guard wantsConnection else {
            publish(snapshot.with(status: .disconnectedByUser))
            return
        }
        await runLink()
    }

    public func userConnect() async {
        isStopped = false
        startListening()
        await restoreIdentity()
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
        isStopped = true
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

    var wantsConnection: Bool {
        preferences.bool(forKey: connectionPreferenceKey) ?? true
    }

    func runLink() async {
        linkGeneration += 1
        let generation = linkGeneration
        let previous = linking
        previous?.cancel()
        await previous?.value
        guard generation == linkGeneration, wantsConnection, !isStopped else { return }
        let link = Task { [weak self] in
            guard let self else { return }
            await establishLink()
        }
        linking = link
        await link.value
    }

    func establishLink() async {
        isLinking = true
        defer { isLinking = false }
        let generation = linkGeneration
        guard await linkUp() else { return }
        guard isCurrent(generation) else {
            await transport.disconnect()
            return
        }
        await didConnect(generation)
    }

    func isCurrent(_ generation: Int) -> Bool {
        generation == linkGeneration && !Task.isCancelled && !isStopped
    }

    func linkUp() async -> Bool {
        guard snapshot.status != .connected, wantsConnection else { return false }
        publish(snapshot.with(status: .searching))
        var failures = 0
        while wantsConnection, !Task.isCancelled {
            let failure: TransportError
            do {
                try await transport.connect()
                framer = driver.makeFramer()
                if await shakeHands() { return true }
                await transport.disconnect()
                failure = .connectFailed
            } catch .bluetoothUnavailable(let issue) {
                publish(snapshot.with(status: .unavailable(issue)))
                return false
            } catch {
                failure = error
            }
            failures += 1
            guard failures < policy.maxAttempts else {
                Self.logger.notice("Connect failed \(failures, privacy: .public) times; waiting")
                publish(snapshot.with(status: .waiting))
                return false
            }
            guard await backOff(after: failure, failures: failures) else { return false }
        }
        return false
    }

    func backOff(after error: TransportError, failures: Int) async -> Bool {
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

    func didConnect(_ generation: Int) async {
        guard wantsConnection else {
            await transport.disconnect()
            return
        }
        await recordIdentity()
        guard isCurrent(generation), wantsConnection else {
            await transport.disconnect()
            return
        }
        publish(snapshot.with(status: .connected))
        await refresh()
        guard snapshot.status == .connected else { return }
        startPolling()
    }

    func startPolling() {
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

    func stopPolling() {
        poller?.cancel()
        poller = nil
    }

    func pollBattery() async {
        guard snapshot.status == .connected, let query = driver.confirmingRequest(for: .battery) else { return }
        await send(query)
    }

    func handle(_ event: LinkEvent) {
        guard !isStopped else { return }
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

    func send(_ request: Data) async {
        do {
            try await transport.send(request)
        } catch {
            Self.logger.error("Send failed: \(String(describing: error), privacy: .public)")
        }
    }

    func startListening() {
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
                    for await connection in connections {
                        await self?.classicDeviceConnected(connection)
                    }
                })
        }
    }

    func recordIdentity() async {
        guard let link = await transport.connectedIdentity() else { return }
        memory.connected(as: link)
        saveMemory()
        await transport.remember(memory.identity)
    }

    func classicDeviceConnected(_ connection: ClassicConnection) {
        guard !isStopped, memory.isOurs(connection) else { return }
        memory.noteClassic(connection)
        saveMemory()
        guard wantsConnection else { return }
        let name = connection.name
        switch snapshot.status {
        case .idle, .connected, .searching, .disconnectedByUser, .unavailable:
            return
        case .retrying, .waiting:
            Self.logger.notice("\(name, privacy: .public) connected to the Mac; reconnecting")
            Task { [weak self] in await self?.runLink() }
        }
    }

    func receive(_ chunk: Data) {
        for packet in framer.push(chunk) {
            apply(packet)
        }
    }

    func apply(_ packet: Data) {
        let updates = driver.updates(from: packet)
        noteHandshakeProgress(updates)
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

    func publish(_ next: DeviceSnapshot) {
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
