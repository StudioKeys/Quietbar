import Testing

@testable import HeadphoneKit

struct DeviceSessionReconnectTests: DeviceSessionHarness {
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

    @Test func bluetoothOffPausesUntilReady() async throws {
        let transport = FakeByteTransport(connectFailures: 1, connectFailure: .bluetoothUnavailable(.poweredOff))
        let session = makeSession(transport)

        await session.start()
        #expect(await session.current.status == .unavailable(.poweredOff))

        await transport.emit(.bluetoothReady)
        try await waitUntil { await session.current.status == .connected }
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
}
