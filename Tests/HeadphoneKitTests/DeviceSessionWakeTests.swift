import Testing

@testable import HeadphoneKit

struct DeviceSessionWakeTests: DeviceSessionHarness {
    private func waitingSession(
        _ transport: FakeByteTransport,
        watcher: FakeConnectionWatcher
    ) async -> DeviceSession {
        await transport.failNextConnects(5)
        let session = makeSession(transport, sleeper: ScriptedSleeper(immediateCount: 10), watcher: watcher)
        await session.start()
        return session
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
        try await waitUntil { watcher.hasHandledAll }
        await settle()

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
        try await waitUntil { watcher.hasHandledAll }
        await settle()

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
        try await waitUntil { watcher.hasHandledAll }
        await settle()

        #expect(await transport.connectCount == 1)
        #expect(await session.current.status == .disconnectedByUser)
    }

    @Test func classicConnectionWhileConnectedIsIgnored() async throws {
        let transport = FakeByteTransport()
        let watcher = FakeConnectionWatcher()
        let session = makeSession(transport, watcher: watcher)
        await session.start()

        watcher.emit("Fake Phones")
        try await waitUntil { watcher.hasHandledAll }
        await settle()

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
        try await waitUntil { watcher.hasHandledAll }
        await settle()
        await transport.releaseHeldConnect(succeeding: false)

        try await waitUntil { await session.current.status == .connected }
        await settle()
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
        try await waitUntil { watcher.hasHandledAll }
        await settle()
        await session.userDisconnect()
        await starting.value
        await settle()

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
        try await waitUntil { watcher.hasHandledAll }
        await settle()

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
        await settle()
        #expect(await transport.connectCount == 2)
    }
}
