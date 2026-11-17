import JBLProtocol
import Testing

@testable import HeadphoneKit

struct HeadphoneSessionApplyTests {
    private static let fastTimeout = Duration.milliseconds(50)

    private func connectedSession(_ transport: FakeTransport) async -> HeadphoneSession {
        let session = HeadphoneSession(transport: transport, replyTimeout: Self.fastTimeout)
        await session.start()
        return session
    }

    @Test func applySetsStateFromReplyNotFromRequest() async throws {
        let transport = FakeTransport(responses: [.setNoiseMode(.talkThru): [Replies.anc]])
        let session = await connectedSession(transport)

        try await session.apply(.setNoiseMode(.talkThru))

        #expect(await session.current.state.noiseMode == .anc)
    }

    @Test func applyTimesOutAndKeepsConfirmedState() async throws {
        let transport = FakeTransport()
        let session = await connectedSession(transport)
        await transport.emit(Replies.anc)
        _ = try await firstSnapshot(of: session) { $0.state.noiseMode == .anc }

        await #expect(throws: ApplyError.timedOut) {
            try await session.apply(.setNoiseMode(.talkThru))
        }
        #expect(await session.current.state.noiseMode == .anc)
        #expect(await session.current.lastError == "Headphones didn't confirm the change")
    }

    @Test func applyFollowsSilentSetWithQuery() async throws {
        let transport = FakeTransport()
        let session = await connectedSession(transport)
        await transport.respond(to: .queryBalance, with: [Replies.balanceCentre])
        let set = Command.setBalance(Balance(offset: 0)!)

        try await session.apply(set)

        #expect(await transport.sent.suffix(2) == [set.frame, Command.queryBalance.frame])
    }

    @Test func applyWhileDisconnectedFailsWithoutSending() async {
        let transport = FakeTransport()
        let session = HeadphoneSession(transport: transport, replyTimeout: Self.fastTimeout)

        await #expect(throws: ApplyError.notConnected) {
            try await session.apply(.setLowVolumeEq(true))
        }
        #expect(await transport.sent.isEmpty)
    }

    @Test func successfulApplyClearsLastError() async throws {
        let transport = FakeTransport()
        let session = await connectedSession(transport)
        try? await session.apply(.setLowVolumeEq(true))
        await transport.respond(to: .setLowVolumeEq(true), with: [Replies.lowVolumeEqOn])

        try await session.apply(.setLowVolumeEq(true))

        #expect(await session.current.lastError == nil)
    }

    @Test func replyArrivingBeforeWaitIsNotLost() async throws {
        let transport = FakeTransport(responses: [.setLowVolumeEq(true): [Replies.lowVolumeEqOn]])
        let session = await connectedSession(transport)

        try await session.apply(.setLowVolumeEq(true))

        #expect(await session.current.state.lowVolumeEq == true)
    }
}
