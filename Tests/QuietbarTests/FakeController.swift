import JBLDevice
import JBLProtocol

@testable import Quietbar

actor FakeController: HeadphoneControlling {
    nonisolated let snapshots: AsyncStream<SessionSnapshot>
    private let snapshotContinuation: AsyncStream<SessionSnapshot>.Continuation
    private let holdsApplies: Bool
    private var held: [CheckedContinuation<Void, Never>] = []
    private(set) var applied: [Command] = []
    private(set) var refreshCount = 0
    private(set) var startCount = 0
    private(set) var connectCount = 0
    private(set) var disconnectCount = 0

    init(holdsApplies: Bool = false) {
        (snapshots, snapshotContinuation) = AsyncStream.makeStream()
        self.holdsApplies = holdsApplies
    }

    func apply(_ command: Command) async throws(ApplyError) {
        applied.append(command)
        guard holdsApplies else { return }
        await withCheckedContinuation { held.append($0) }
    }

    func start() async { startCount += 1 }
    func refresh() async { refreshCount += 1 }
    func userConnect() async { connectCount += 1 }
    func userDisconnect() async { disconnectCount += 1 }

    func releaseAll() {
        let waiting = held
        held = []
        for continuation in waiting { continuation.resume() }
    }

    func publish(_ snapshot: SessionSnapshot) {
        snapshotContinuation.yield(snapshot)
    }
}

struct WaitTimedOut: Error {}

func waitUntil(
    within timeout: Duration = .seconds(1),
    _ condition: @Sendable () async -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while await !condition() {
        guard ContinuousClock.now < deadline else { throw WaitTimedOut() }
        try await Task.sleep(for: .milliseconds(5))
    }
}

func snapshot(
    _ status: ConnectionStatus = .connected,
    noiseMode: NoiseMode? = nil,
    battery: Int? = nil
) -> SessionSnapshot {
    var state = HeadphoneState.empty
    if let noiseMode { state = state.applying(.noiseMode(noiseMode)) }
    if let battery { state = state.applying(.battery(Battery(percent: battery, isCharging: false))) }
    return SessionSnapshot(status: status, state: state, lastError: nil)
}
