import Foundation
import Testing

@testable import HeadphoneKit

struct DeviceSessionTests {
    private func makeSession(
        _ transport: FakeByteTransport,
        timeout: Duration = .milliseconds(50),
        store: InMemoryPreferenceStore = InMemoryPreferenceStore(),
        sleeper: ScriptedSleeper = ScriptedSleeper(immediateCount: 0),
        watcher: FakeConnectionWatcher? = nil,
        deviceID: String? = nil,
        driver: FakeDriver = FakeDriver()
    ) -> DeviceSession {
        DeviceSession(
            driver: driver,
            transport: transport,
            replyTimeout: timeout,
            sleep: sleeper.closure,
            preferences: store,
            watcher: watcher,
            deviceID: deviceID
        )
    }

    private static let hello = Data([0x09])

    private var handshakeDriver: FakeDriver {
        var driver = FakeDriver()
        driver.handshakeRequests = [Self.hello]
        driver.readySetting = "mode"
        return driver
    }

    @Test func chunksPassThroughDriverFramer() async throws {
        var driver = FakeDriver()
        driver.framesOnNewline = true
        let transport = FakeByteTransport()
        let session = makeSession(transport, driver: driver)
        await session.start()

        await transport.emit(Data([0x02, 0x01]))
        await transport.emit(Data([0x05, 0x0A]))

        try await waitUntil { await session.current.state["volume"] == .level(5) }
    }

    @Test func connectedOnlyAfterDriverReady() async {
        let transport = FakeByteTransport(responses: [Self.hello: [FakeDriver.reply("mode", 1)]])

        let session = makeSession(transport, driver: handshakeDriver)
        await session.start()

        #expect(await session.current.status == .connected)
        #expect(await transport.sent.first == Self.hello)
    }

    @Test func handshakeResentOnceBeforeGivingUp() async throws {
        let transport = FakeByteTransport()
        let session = makeSession(transport, sleeper: ScriptedSleeper(immediateCount: 0), driver: handshakeDriver)
        let starting = Task { await session.start() }
        defer { starting.cancel() }

        try await waitUntil { await session.current.status == .retrying(after: .seconds(1), phoneHint: true) }
        #expect(await transport.sent.filter { $0 == Self.hello }.count == 2)
        #expect(await transport.disconnectCount == 1)
    }

    @Test func handshakeTimeoutCountsAsFailedAttempt() async throws {
        let transport = FakeByteTransport()
        let session = makeSession(transport, sleeper: ScriptedSleeper(immediateCount: 10), driver: handshakeDriver)

        await session.start()

        #expect(await session.current.status == .waiting)
        #expect(await transport.connectCount == 5)
    }

    @Test func lastKnownStateDoesNotSatisfyHandshake() async throws {
        let transport = FakeByteTransport(responses: [Self.hello: [FakeDriver.reply("mode", 1)]])
        let sleeper = ScriptedSleeper(immediateCount: 10, blocksFrom: .seconds(300))
        let session = makeSession(transport, sleeper: sleeper, driver: handshakeDriver)
        await session.start()

        await transport.respond(to: Self.hello, with: [])
        await transport.emit(.disconnected)

        try await waitUntil(within: .seconds(3)) { await session.current.status == .waiting }
    }

    @Test func disconnectDuringHandshakeStopsWaitingAtOnce() async throws {
        let transport = FakeByteTransport()
        let session = makeSession(transport, timeout: .seconds(2), driver: handshakeDriver)
        let starting = Task { await session.start() }
        defer { starting.cancel() }
        try await waitUntil { await transport.sent.contains(Self.hello) }

        await session.userDisconnect()
        let connecting = Task { await session.userConnect() }
        defer { connecting.cancel() }

        try await waitUntil(within: .milliseconds(500)) { await transport.connectCount == 2 }
        await session.userDisconnect()
        #expect(await session.current.status == .disconnectedByUser)
    }

    @Test func stopDisconnectsAndEndsIdle() async {
        let transport = FakeByteTransport()
        let session = makeSession(transport)
        await session.start()

        await session.stop()

        #expect(await transport.disconnectCount == 1)
        #expect(await session.current.status == .idle)
    }

    @Test func stoppedSessionIgnoresLinkEvents() async throws {
        let transport = FakeByteTransport()
        let session = makeSession(transport)
        await session.start()

        await session.stop()
        await transport.emit(.disconnected)
        await transport.emit(.bluetoothReady)
        try await Task.sleep(for: .milliseconds(50))

        #expect(await transport.connectCount == 1)
        #expect(await session.current.status == .idle)
    }

    @Test func stopWhileRecordingIdentityNeverPublishesConnected() async throws {
        let transport = FakeByteTransport(identity: Self.identity, holdsIdentity: true)
        let session = makeSession(transport, deviceID: "dev")
        let starting = Task { await session.start() }
        defer { starting.cancel() }
        try await waitUntil { await transport.identityRequested }

        await session.stop()
        await transport.releaseIdentity()
        try await Task.sleep(for: .milliseconds(50))

        #expect(await session.current.status == .idle)
    }

    @Test func userConnectRestoresRememberedIdentity() async {
        let store = InMemoryPreferenceStore()
        store.set(Self.identity.encoded, forKey: DeviceSession.identityKey(for: "dev"))
        store.set(false, forKey: DeviceSession.connectionKey(for: "dev"))
        let transport = FakeByteTransport()
        let session = makeSession(transport, store: store, deviceID: "dev")

        await session.userConnect()

        #expect(await transport.rememberedAtFirstConnect == Self.identity)
        #expect(await session.current.deviceName == "Jis Cans")
    }

    @Test func stopKeepsConnectionChoice() async {
        let store = InMemoryPreferenceStore()
        let session = makeSession(FakeByteTransport(), store: store)
        await session.start()

        await session.stop()
        let next = FakeByteTransport()
        await makeSession(next, store: store).start()

        #expect(await next.connectCount == 1)
        #expect(store.bool(forKey: DeviceSession.wantsConnectionKey) != false)
    }

    @Test func stopDuringPendingConnectEndsIdle() async throws {
        let transport = FakeByteTransport(holdsConnect: true)
        let session = makeSession(transport, sleeper: ScriptedSleeper(immediateCount: 10))
        let starting = Task { await session.start() }
        defer { starting.cancel() }
        try await waitUntil { await transport.connectCount == 1 }

        await session.stop()
        try await Task.sleep(for: .milliseconds(50))

        #expect(await session.current.status == .idle)
        #expect(await transport.connectCount == 1)
    }

    @Test func supersededLinkDropsItsConnection() async throws {
        let transport = FakeByteTransport(holdsConnect: true)
        let session = makeSession(transport)
        let starting = Task { await session.start() }
        defer { starting.cancel() }
        try await waitUntil { await transport.connectCount == 1 }

        let connecting = Task { await session.userConnect() }
        try await Task.sleep(for: .milliseconds(20))
        await transport.releaseHeldConnect(succeeding: true)
        await connecting.value

        #expect(await transport.disconnectCount == 1)
        #expect(await transport.connectCount == 2)
        #expect(await session.current.status == .connected)
    }

    @Test func userConnectWithoutStartStillHandlesLinkEvents() async throws {
        let transport = FakeByteTransport()
        let session = makeSession(transport)
        await session.userConnect()

        await transport.emit(.disconnected)

        try await waitUntil { await transport.connectCount == 2 }
    }

    private static let identity = DeviceIdentity(name: "Jis Cans", linkID: "LINK-1", classicAddress: nil)

    private func storedIdentity(_ store: InMemoryPreferenceStore, _ id: String = "dev") -> DeviceIdentity? {
        store.string(forKey: DeviceSession.identityKey(for: id)).flatMap(DeviceIdentity.decode)
    }

    @Test func identityRememberedAfterConnect() async {
        let store = InMemoryPreferenceStore()
        let transport = FakeByteTransport(identity: Self.identity)

        let session = makeSession(transport, store: store, deviceID: "dev")
        await session.start()

        #expect(storedIdentity(store) == Self.identity)
        #expect(await session.current.deviceName == "Jis Cans")
    }

    @Test func rememberedIdentityPassedToTransportOnStart() async throws {
        let store = InMemoryPreferenceStore()
        store.set(Self.identity.encoded, forKey: DeviceSession.identityKey(for: "dev"))
        let transport = FakeByteTransport(holdsConnect: true)
        let session = makeSession(transport, store: store, deviceID: "dev")

        let starting = Task { await session.start() }
        defer { starting.cancel() }

        try await waitUntil { await transport.connectCount == 1 }
        #expect(await transport.remembered == Self.identity)
        #expect(await session.current.deviceName == "Jis Cans")
    }

    @Test func wakeMatchesRememberedAddressAfterRename() async throws {
        let store = InMemoryPreferenceStore()
        let known = DeviceIdentity(name: "Jis Cans", linkID: "LINK-1", classicAddress: "AA")
        store.set(known.encoded, forKey: DeviceSession.identityKey(for: "dev"))
        let transport = FakeByteTransport(connectFailures: 5)
        let watcher = FakeConnectionWatcher()
        let session = makeSession(
            transport, store: store, sleeper: ScriptedSleeper(immediateCount: 10), watcher: watcher, deviceID: "dev")
        await session.start()

        watcher.emit("Living room", address: "AA")

        try await waitUntil { await session.current.status == .connected }
    }

    @Test func otherDeviceWithSameNameIgnoredOnceAddressKnown() async throws {
        let store = InMemoryPreferenceStore()
        let known = DeviceIdentity(name: "Fake Phones", linkID: "LINK-1", classicAddress: "AA")
        store.set(known.encoded, forKey: DeviceSession.identityKey(for: "dev"))
        let transport = FakeByteTransport(connectFailures: 5)
        let watcher = FakeConnectionWatcher()
        let session = makeSession(
            transport, store: store, sleeper: ScriptedSleeper(immediateCount: 10), watcher: watcher, deviceID: "dev")
        await session.start()

        watcher.emit("Fake Phones", address: "BB")
        try await Task.sleep(for: .milliseconds(50))

        #expect(await session.current.status == .waiting)
    }

    @Test func firstNameMatchedWakeRecordsClassicAddress() async throws {
        let store = InMemoryPreferenceStore()
        let transport = FakeByteTransport(connectFailures: 5, identity: Self.identity)
        let watcher = FakeConnectionWatcher()
        let session = makeSession(
            transport, store: store, sleeper: ScriptedSleeper(immediateCount: 10), watcher: watcher, deviceID: "dev")
        await session.start()

        watcher.emit("Fake Phones", address: "CC")

        try await waitUntil { await session.current.status == .connected }
        #expect(storedIdentity(store)?.classicAddress == "CC")
    }

    @Test func audioNameReportedBeforeStartNamesTheHeadphones() async {
        let store = InMemoryPreferenceStore()
        let transport = FakeByteTransport(identity: Self.identity)
        let watcher = FakeConnectionWatcher()
        watcher.emit("Fake Phones", address: "CC")
        let session = makeSession(transport, store: store, watcher: watcher, deviceID: "dev")

        await session.start()
        try? await Task.sleep(for: .milliseconds(30))

        #expect(await session.current.deviceName == "Fake Phones")
        #expect(storedIdentity(store)?.classicAddress == "CC")
    }

    @Test func sessionsUsePerDeviceKey() async {
        let store = InMemoryPreferenceStore()
        store.set(false, forKey: DeviceSession.connectionKey(for: "a"))
        let other = FakeByteTransport()

        await makeSession(other, store: store, deviceID: "b").start()

        #expect(await other.connectCount == 1)
    }

    private func waitingSession(
        _ transport: FakeByteTransport,
        watcher: FakeConnectionWatcher
    ) async -> DeviceSession {
        await transport.failNextConnects(5)
        let session = makeSession(transport, sleeper: ScriptedSleeper(immediateCount: 10), watcher: watcher)
        await session.start()
        return session
    }

    @Test func matchingClassicConnectionWakesWaitingSession() async throws {
        let transport = FakeByteTransport()
        let watcher = FakeConnectionWatcher()
        let session = await waitingSession(transport, watcher: watcher)

        watcher.emit("My Fake Phones")

        try await waitUntil { await session.current.status == .connected }
        #expect(await transport.connectCount == 6)
    }

    @Test func nonMatchingClassicConnectionIsIgnored() async throws {
        let transport = FakeByteTransport()
        let watcher = FakeConnectionWatcher()
        let session = await waitingSession(transport, watcher: watcher)

        watcher.emit("Keyboard")
        try await Task.sleep(for: .milliseconds(50))

        #expect(await transport.connectCount == 5)
        #expect(await session.current.status == .waiting)
    }

    @Test func classicConnectionAfterUserDisconnectIsIgnored() async throws {
        let transport = FakeByteTransport()
        let watcher = FakeConnectionWatcher()
        let session = makeSession(transport, watcher: watcher)
        await session.start()
        await session.userDisconnect()

        watcher.emit("Fake Phones")
        try await Task.sleep(for: .milliseconds(50))

        #expect(await transport.connectCount == 1)
        #expect(await session.current.status == .disconnectedByUser)
    }

    @Test func classicConnectionWhileConnectedIsIgnored() async throws {
        let transport = FakeByteTransport()
        let watcher = FakeConnectionWatcher()
        let session = makeSession(transport, watcher: watcher)
        await session.start()

        watcher.emit("Fake Phones")
        try await Task.sleep(for: .milliseconds(50))

        #expect(await transport.connectCount == 1)
        #expect(await session.current.status == .connected)
    }

    @Test func wakesDuringPendingConnectRunOneRound() async throws {
        let transport = FakeByteTransport(connectFailures: 1, holdsConnect: true, heldConnectNumber: 2)
        let watcher = FakeConnectionWatcher()
        let session = makeSession(transport, sleeper: ScriptedSleeper(immediateCount: 10), watcher: watcher)
        let starting = Task { await session.start() }
        defer { starting.cancel() }
        try await waitUntil { await transport.connectCount == 2 }

        watcher.emit("Fake Phones")
        watcher.emit("Fake Phones")
        try await Task.sleep(for: .milliseconds(20))
        await transport.releaseHeldConnect(succeeding: false)

        try await waitUntil { await session.current.status == .connected }
        try await Task.sleep(for: .milliseconds(50))
        #expect(await transport.connectCount == 3)
    }

    @Test func disconnectWhileWakeWaitsOnPendingConnectStaysDisconnected() async throws {
        let transport = FakeByteTransport(connectFailures: 1, holdsConnect: true, heldConnectNumber: 2)
        let watcher = FakeConnectionWatcher()
        let session = makeSession(transport, sleeper: ScriptedSleeper(immediateCount: 10), watcher: watcher)
        let starting = Task { await session.start() }
        defer { starting.cancel() }
        try await waitUntil { await transport.connectCount == 2 }

        watcher.emit("Fake Phones")
        try await Task.sleep(for: .milliseconds(20))
        await session.userDisconnect()
        try await Task.sleep(for: .milliseconds(100))

        #expect(await session.current.status == .disconnectedByUser)
    }

    @Test func connectionReportedBeforeStartDoesNotRestartFirstAttempt() async throws {
        let transport = FakeByteTransport(holdsConnect: true)
        let watcher = FakeConnectionWatcher()
        let session = makeSession(transport, watcher: watcher)
        watcher.emit("Fake Phones")
        let starting = Task { await session.start() }
        defer { starting.cancel() }
        try await waitUntil { await transport.connectCount == 1 }
        try await Task.sleep(for: .milliseconds(20))

        await transport.releaseHeldConnect(succeeding: false)

        try await waitUntil { await session.current.status == .retrying(after: .seconds(1), phoneHint: true) }
        #expect(await transport.connectCount == 1)
    }

    @Test func wakeDuringBackOffRestartsSingleRound() async throws {
        let transport = FakeByteTransport(connectFailures: 1)
        let watcher = FakeConnectionWatcher()
        let session = makeSession(transport, sleeper: ScriptedSleeper(immediateCount: 0), watcher: watcher)
        let starting = Task { await session.start() }
        defer { starting.cancel() }
        try await waitUntil { await session.current.status == .retrying(after: .seconds(1), phoneHint: true) }

        watcher.emit("Fake Phones")

        try await waitUntil { await session.current.status == .connected }
        try await Task.sleep(for: .milliseconds(50))
        #expect(await transport.connectCount == 2)
    }

    @Test func startConnectsAndSendsDriverRefreshRequests() async {
        let transport = FakeByteTransport()

        await makeSession(transport).start()

        #expect(await transport.connectCount == 1)
        #expect(await transport.sent == FakeDriver().refreshRequests)
    }

    @Test func repliesFoldIntoDeviceState() async throws {
        let transport = FakeByteTransport(responses: [
            FakeDriver.query(0): [FakeDriver.reply("power", 1)],
            FakeDriver.batteryQuery: [FakeDriver.battery(80)],
        ])
        let session = makeSession(transport)

        await session.start()

        try await waitUntil { await session.current.state.battery?.percent == 80 }
        #expect(await session.current.state["power"] == .level(1))
        #expect(await session.current.status == .connected)
    }

    @Test func unrecognisedPacketLeavesStateUnchanged() async throws {
        let transport = FakeByteTransport()
        let session = makeSession(transport)
        await session.start()

        await transport.emit(Data([0xEE, 0x01]))
        await transport.emit(FakeDriver.reply("volume", 4))

        try await waitUntil { await session.current.state["volume"] != nil }
        #expect(await session.current.state == DeviceState.empty.applying([.setting("volume", .level(4))]))
    }

    @Test func applySendsDriverRequestAndWaitsForSettingUpdate() async throws {
        let transport = FakeByteTransport(responses: [FakeDriver.set("volume", 7): [FakeDriver.reply("volume", 6)]])
        let session = makeSession(transport)
        await session.start()

        try await session.apply(SettingChange(id: "volume", value: .level(7)))

        #expect(await session.current.state["volume"] == .level(6))
        #expect(await session.current.lastError == nil)
    }

    @Test func silentSetIsFollowedByConfirmingRequest() async throws {
        let transport = FakeByteTransport(responses: [FakeDriver.query(1): [FakeDriver.reply("volume", 3)]])
        let session = makeSession(transport)
        await session.start()
        try await waitUntil { await session.current.state["volume"] == .level(3) }

        try await session.apply(SettingChange(id: "volume", value: .level(3)))

        #expect(await transport.sent.suffix(2) == [FakeDriver.set("volume", 3), FakeDriver.query(1)])
    }

    @Test func applyTimesOutWhenDeviceStaysSilent() async {
        let transport = FakeByteTransport()
        let session = makeSession(transport)
        await session.start()

        await #expect(throws: ApplyError.timedOut) {
            try await session.apply(SettingChange(id: "power", value: .bool(true)))
        }
        #expect(await session.current.lastError == "Headphones didn't confirm the change")
    }

    @Test func applyUnsupportedChangeThrows() async {
        let transport = FakeByteTransport()
        let session = makeSession(transport)
        await session.start()

        await #expect(throws: ApplyError.unsupported) {
            try await session.apply(SettingChange(id: "unknown", value: .bool(true)))
        }
    }

    @Test func applyWhileDisconnectedSendsNothing() async {
        let transport = FakeByteTransport()
        let session = makeSession(transport)

        await #expect(throws: ApplyError.notConnected) {
            try await session.apply(SettingChange(id: "power", value: .bool(true)))
        }
        #expect(await transport.sent.isEmpty)
    }

    @Test func reconnectBacksOffThenSucceeds() async {
        let transport = FakeByteTransport(connectFailures: 3)
        let sleeper = ScriptedSleeper(immediateCount: 3)

        await makeSession(transport, sleeper: sleeper).start()

        #expect(await sleeper.requested(below: .seconds(300)) == [.seconds(1), .seconds(2), .seconds(5)])
        #expect(await transport.connectCount == 4)
    }

    @Test func reconnectGivesUpAfterMaxAttempts() async {
        let transport = FakeByteTransport(connectFailures: 10)
        let sleeper = ScriptedSleeper(immediateCount: 10)
        let session = makeSession(transport, sleeper: sleeper)

        await session.start()

        #expect(await transport.connectCount == 5)
        #expect(await sleeper.requested(below: .seconds(300)) == [.seconds(1), .seconds(2), .seconds(5), .seconds(10)])
        #expect(await session.current.status == .waiting)
    }

    @Test func dropWhileConnectedEndsInWaiting() async throws {
        let transport = FakeByteTransport()
        let session = makeSession(transport, sleeper: ScriptedSleeper(immediateCount: 10, blocksFrom: .seconds(300)))
        await session.start()

        await transport.failNextConnects(10)
        await transport.emit(.disconnected)

        try await waitUntil { await session.current.status == .waiting }
        #expect(await transport.connectCount == 6)
    }

    @Test func connectAfterWaitingStartsFreshRound() async {
        let transport = FakeByteTransport(connectFailures: 5)
        let session = makeSession(transport, sleeper: ScriptedSleeper(immediateCount: 10))
        await session.start()

        await session.userConnect()

        #expect(await session.current.status == .connected)
        #expect(await transport.connectCount == 6)
    }

    @Test func bluetoothReadyAfterWaitingRetries() async throws {
        let transport = FakeByteTransport(connectFailures: 5)
        let session = makeSession(transport, sleeper: ScriptedSleeper(immediateCount: 10))
        await session.start()

        await transport.emit(.bluetoothReady)

        try await waitUntil { await session.current.status == .connected }
    }

    @Test func connectFailureShowsPhoneHint() async throws {
        let transport = FakeByteTransport(connectFailures: 1, connectFailure: .connectFailed)
        let session = makeSession(transport)

        let starting = Task { await session.start() }
        defer { starting.cancel() }

        try await waitUntil { await session.current.status == .retrying(after: .seconds(1), phoneHint: true) }
    }

    @Test func unexpectedDisconnectReconnects() async throws {
        let transport = FakeByteTransport()
        let session = makeSession(transport)
        await session.start()

        await transport.emit(.disconnected)

        try await waitUntil { await transport.connectCount == 2 }
    }

    @Test func userDisconnectIsRememberedAcrossStart() async throws {
        let transport = FakeByteTransport()
        let store = InMemoryPreferenceStore()
        let session = makeSession(transport, store: store)
        await session.start()

        await session.userDisconnect()
        await transport.emit(.disconnected)
        try await Task.sleep(for: .milliseconds(50))
        let relaunched = makeSession(FakeByteTransport(), store: store)
        await relaunched.start()

        #expect(await transport.connectCount == 1)
        #expect(await relaunched.current.status == .disconnectedByUser)
    }

    @Test func userConnectResumes() async {
        let transport = FakeByteTransport()
        let store = InMemoryPreferenceStore()
        store.set(false, forKey: DeviceSession.wantsConnectionKey)
        let session = makeSession(transport, store: store)
        await session.start()

        await session.userConnect()

        #expect(await session.current.status == .connected)
    }

    @Test func bluetoothOffPausesUntilReady() async throws {
        let transport = FakeByteTransport(connectFailures: 1, connectFailure: .bluetoothUnavailable(.poweredOff))
        let session = makeSession(transport)

        await session.start()
        #expect(await session.current.status == .unavailable(.poweredOff))

        await transport.emit(.bluetoothReady)
        try await waitUntil { await session.current.status == .connected }
    }

    @Test func batteryIsPolledWithDriverRequest() async throws {
        let transport = FakeByteTransport()
        let sleeper = ScriptedSleeper(immediateCount: 2)

        let session = makeSession(transport, sleeper: sleeper)
        await session.start()

        try await waitUntil { await transport.sent.filter { $0 == FakeDriver.batteryQuery }.count == 3 }
        #expect(await session.current.status == .connected)
    }

    @Test func reconnectingSettingIsSentWithoutWaitingForConfirmation() async throws {
        let transport = FakeByteTransport()
        let session = makeSession(transport, timeout: .seconds(5))
        await session.start()

        let started = ContinuousClock.now
        try await session.apply(SettingChange(id: "codec", value: .bool(true)))

        #expect(ContinuousClock.now - started < .seconds(1))
        #expect(await transport.sent.last == FakeDriver.set("codec", 1))
        #expect(await session.current.lastError == nil)
    }

    @Test func linkDroppedDuringFirstRefreshReconnects() async throws {
        let transport = FakeByteTransport(dropLinkOnSend: FakeDriver.query(1))
        let session = makeSession(transport, sleeper: ScriptedSleeper(immediateCount: 5))

        await session.start()

        try await waitUntil { await transport.connectCount == 2 }
        try await waitUntil { await session.current.status == .connected }
    }

    @Test func connectAfterDisconnectDuringBackOffConnectsAtOnce() async throws {
        let transport = FakeByteTransport(connectFailures: 1)
        let session = makeSession(transport)
        let starting = Task { await session.start() }
        defer { starting.cancel() }
        try await waitUntil { await session.current.status == .retrying(after: .seconds(1), phoneHint: true) }

        await session.userDisconnect()
        await session.userConnect()

        #expect(await session.current.status == .connected)
        #expect(await transport.connectCount == 2)
    }

    @Test func disconnectDuringPendingConnectShowsDisconnected() async throws {
        let transport = FakeByteTransport(holdsConnect: true)
        let session = makeSession(transport)
        let starting = Task { await session.start() }
        defer { starting.cancel() }
        try await waitUntil { await transport.connectCount == 1 }

        await session.userDisconnect()
        try await Task.sleep(for: .milliseconds(50))

        #expect(await session.current.status == .disconnectedByUser)
    }
}
