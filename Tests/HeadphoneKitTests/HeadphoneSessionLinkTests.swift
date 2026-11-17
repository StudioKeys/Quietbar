import JBLProtocol
import Testing

@testable import HeadphoneKit

struct HeadphoneSessionLinkTests {
    private static let pollLimit = Duration.seconds(300)

    private func session(
        _ transport: FakeTransport,
        store: InMemoryPreferenceStore = InMemoryPreferenceStore(),
        sleeper: ScriptedSleeper = ScriptedSleeper(immediateCount: 0)
    ) -> HeadphoneSession {
        HeadphoneSession(
            transport: transport,
            replyTimeout: .milliseconds(50),
            sleep: sleeper.closure,
            preferences: store
        )
    }

    @Test func reconnectLoopBacksOffWhileTransportFails() async {
        let transport = FakeTransport(connectFailures: 3)
        let sleeper = ScriptedSleeper(immediateCount: 3)

        await session(transport, sleeper: sleeper).start()

        #expect(await sleeper.requested(below: Self.pollLimit) == [.seconds(1), .seconds(2), .seconds(5)])
        #expect(await transport.connectCount == 4)
    }

    @Test func connectFailureSurfacesPhoneHint() async throws {
        let transport = FakeTransport(connectFailures: 1, connectFailure: .connectFailed)
        let session = session(transport)

        let starting = Task { await session.start() }
        defer { starting.cancel() }

        try await waitUntil { await session.current.status == .retrying(after: .seconds(1), phoneHint: true) }
    }

    @Test func missingHeadsetRetriesWithoutPhoneHint() async throws {
        let transport = FakeTransport(connectFailures: 1, connectFailure: .notFound)
        let session = session(transport)

        let starting = Task { await session.start() }
        defer { starting.cancel() }

        try await waitUntil { await session.current.status == .retrying(after: .seconds(1), phoneHint: false) }
    }

    @Test func unexpectedDisconnectTriggersReconnect() async throws {
        let transport = FakeTransport()
        let session = session(transport)
        await session.start()

        await transport.emit(.disconnected)

        try await waitUntil { await transport.connectCount == 2 }
        try await waitUntil { await session.current.status == .connected }
    }

    @Test func userDisconnectPersistsAndStopsReconnect() async throws {
        let transport = FakeTransport()
        let store = InMemoryPreferenceStore()
        let session = session(transport, store: store)
        await session.start()

        await session.userDisconnect()
        await transport.emit(.disconnected)
        try await Task.sleep(for: .milliseconds(50))

        #expect(store.bool(forKey: HeadphoneSession.wantsConnectionKey) == false)
        #expect(await transport.disconnectCount == 1)
        #expect(await transport.connectCount == 1)
        #expect(await session.current.status == .disconnectedByUser)
    }

    @Test func startHonoursPersistedDisconnect() async {
        let transport = FakeTransport()
        let store = InMemoryPreferenceStore()
        store.set(false, forKey: HeadphoneSession.wantsConnectionKey)

        let session = session(transport, store: store)
        await session.start()

        #expect(await transport.connectCount == 0)
        #expect(await transport.sent.isEmpty)
        #expect(await session.current.status == .disconnectedByUser)
    }

    @Test func userConnectPersistsAndConnects() async {
        let transport = FakeTransport()
        let store = InMemoryPreferenceStore()
        store.set(false, forKey: HeadphoneSession.wantsConnectionKey)
        let session = session(transport, store: store)
        await session.start()

        await session.userConnect()

        #expect(store.bool(forKey: HeadphoneSession.wantsConnectionKey) == true)
        #expect(await session.current.status == .connected)
        #expect(await transport.sent == Command.refreshAll.map(\.frame))
    }

    @Test func bluetoothUnavailablePausesReconnect() async throws {
        let transport = FakeTransport(connectFailures: 1, connectFailure: .bluetoothUnavailable(.poweredOff))
        let sleeper = ScriptedSleeper(immediateCount: 0)
        let session = session(transport, sleeper: sleeper)

        await session.start()

        #expect(await session.current.status == .unavailable(.poweredOff))
        #expect(await sleeper.requested(below: Self.pollLimit).isEmpty)

        await transport.emit(.bluetoothReady)

        try await waitUntil { await session.current.status == .connected }
    }

    @Test func bluetoothTurnedOffWhileConnectedShowsUnavailable() async throws {
        let transport = FakeTransport()
        let session = session(transport)
        await session.start()

        await transport.emit(.bluetoothUnavailable(.poweredOff))

        try await waitUntil { await session.current.status == .unavailable(.poweredOff) }
        #expect(await transport.connectCount == 1)
    }

    @Test func batteryPolledWhileConnected() async throws {
        let transport = FakeTransport()
        let sleeper = ScriptedSleeper(immediateCount: 2)
        let session = session(transport, sleeper: sleeper)

        await session.start()

        try await waitUntil { await transport.sent.filter { $0 == Command.queryBattery.frame }.count == 3 }
        #expect(await sleeper.requested.allSatisfy { $0 == Self.pollLimit })
    }
}
