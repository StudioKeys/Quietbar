import Foundation
import HeadphoneKit

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

actor ScriptedSleeper {
    private let immediateCount: Int
    private let blocksFrom: Duration?
    private(set) var requested: [Duration] = []

    init(immediateCount: Int = .max, blocksFrom: Duration? = nil) {
        self.immediateCount = immediateCount
        self.blocksFrom = blocksFrom
    }

    func sleep(_ duration: Duration) async throws {
        requested.append(duration)
        let alwaysBlocks = blocksFrom.map { duration >= $0 } ?? false
        guard alwaysBlocks || requested.count > immediateCount else { return }
        try await Task.sleep(for: .seconds(3600))
    }

    func requested(below limit: Duration) -> [Duration] {
        requested.filter { $0 < limit }
    }

    nonisolated var closure: Sleeper {
        { [self] duration in try await self.sleep(duration) }
    }
}
