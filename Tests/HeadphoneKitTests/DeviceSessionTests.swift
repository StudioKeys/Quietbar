import Foundation
import Testing

@testable import HeadphoneKit

struct DeviceSessionTests {
    private func makeSession(
        _ transport: FakeByteTransport,
        timeout: Duration = .milliseconds(50),
        store: InMemoryPreferenceStore = InMemoryPreferenceStore(),
        sleeper: ScriptedSleeper = ScriptedSleeper(immediateCount: 0)
    ) -> DeviceSession {
        DeviceSession(
            driver: FakeDriver(),
            transport: transport,
            replyTimeout: timeout,
            sleep: sleeper.closure,
            preferences: store
        )
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
}
