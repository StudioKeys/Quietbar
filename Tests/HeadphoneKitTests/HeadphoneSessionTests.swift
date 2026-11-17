import JBLProtocol
import Testing

@testable import HeadphoneKit

struct HeadphoneSessionTests {
    @Test func startConnectsAndQueriesEverySetting() async {
        let transport = FakeTransport()
        let session = HeadphoneSession(transport: transport)

        await session.start()

        #expect(await transport.connectCount == 1)
        #expect(await transport.sent == Command.refreshAll.map(\.frame))
    }

    @Test func snapshotReflectsRepliesAfterRefresh() async throws {
        let transport = FakeTransport(responses: [
            .queryNoiseMode: [Replies.anc], .queryBattery: [Replies.battery90],
        ])
        let session = HeadphoneSession(transport: transport)

        await session.start()
        let snapshot = try await firstSnapshot(of: session) { $0.state.battery != nil }

        #expect(snapshot.status == .connected)
        #expect(snapshot.state.noiseMode == .anc)
        #expect(snapshot.state.battery?.percent == 90)
    }

    @Test func unsolicitedFrameUpdatesState() async throws {
        let transport = FakeTransport()
        let session = HeadphoneSession(transport: transport)
        await session.start()

        await transport.emit(Replies.talkThru)
        let snapshot = try await firstSnapshot(of: session) { $0.state.noiseMode != nil }

        #expect(snapshot.state.noiseMode == .talkThru)
    }

    @Test func garbageFrameLeavesStateUnchanged() async throws {
        let transport = FakeTransport()
        let session = HeadphoneSession(transport: transport)
        await session.start()

        await transport.emit(Replies.deviceStatus)
        await transport.emit(Replies.lowVolumeEqOn)
        let snapshot = try await firstSnapshot(of: session) { $0.state.lowVolumeEq != nil }

        #expect(snapshot.state == HeadphoneState.empty.applying(.lowVolumeEq(true)))
    }

    @Test func refreshSendsEveryQueryAgain() async {
        let transport = FakeTransport()
        let session = HeadphoneSession(transport: transport)
        await session.start()

        await session.refresh()

        #expect(await transport.sent == (Command.refreshAll + Command.refreshAll).map(\.frame))
    }
}
