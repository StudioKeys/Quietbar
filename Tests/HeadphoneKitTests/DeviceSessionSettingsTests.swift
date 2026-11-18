import Foundation
import Testing

@testable import HeadphoneKit

struct DeviceSessionSettingsTests: DeviceSessionHarness {
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
}
