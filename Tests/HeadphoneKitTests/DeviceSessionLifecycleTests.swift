import Foundation
import Testing

@testable import HeadphoneKit

struct DeviceSessionLifecycleTests: DeviceSessionHarness {
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
        try await waitUntil { transport.hasHandledAllEvents }
        await settle()

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
        await starting.value

        #expect(await session.current.status == .idle)
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
        await starting.value

        #expect(await session.current.status == .idle)
        #expect(await transport.connectCount == 1)
    }

    @Test func supersededLinkDropsItsConnection() async throws {
        let transport = FakeByteTransport(holdsConnect: true)
        let store = InMemoryPreferenceStore()
        let session = makeSession(transport, store: store)
        let starting = Task { await session.start() }
        defer { starting.cancel() }
        try await waitUntil { await transport.connectCount == 1 }

        let connecting = Task { await session.userConnect() }
        try await waitUntil { store.bool(forKey: DeviceSession.wantsConnectionKey) == true }
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

    @Test func userDisconnectIsRememberedAcrossStart() async throws {
        let transport = FakeByteTransport()
        let store = InMemoryPreferenceStore()
        let session = makeSession(transport, store: store)
        await session.start()

        await session.userDisconnect()
        await transport.emit(.disconnected)
        try await waitUntil { transport.hasHandledAllEvents }
        await settle()
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

    @Test func disconnectDuringPendingConnectShowsDisconnected() async throws {
        let transport = FakeByteTransport(holdsConnect: true)
        let session = makeSession(transport)
        let starting = Task { await session.start() }
        defer { starting.cancel() }
        try await waitUntil { await transport.connectCount == 1 }

        await session.userDisconnect()
        await starting.value

        #expect(await session.current.status == .disconnectedByUser)
    }
}
