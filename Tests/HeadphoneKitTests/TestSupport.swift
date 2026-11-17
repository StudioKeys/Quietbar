import Foundation
import HeadphoneKit
import JBLProtocol

struct WaitTimedOut: Error {}

func frame(_ hex: String) -> Frame {
    let bytes = hex.split(separator: " ").compactMap { UInt8($0, radix: 16) }
    return try! Frame.decode(Data(bytes))
}

func firstSnapshot(
    of session: HeadphoneSession,
    within timeout: Duration = .seconds(1),
    where predicate: @escaping @Sendable (SessionSnapshot) -> Bool
) async throws -> SessionSnapshot {
    try await withThrowingTaskGroup(of: SessionSnapshot?.self) { group in
        group.addTask {
            for await snapshot in session.snapshots where predicate(snapshot) { return snapshot }
            return nil
        }
        group.addTask {
            try await Task.sleep(for: timeout)
            throw WaitTimedOut()
        }
        defer { group.cancelAll() }
        guard let snapshot = try await group.next() ?? nil else { throw WaitTimedOut() }
        return snapshot
    }
}

enum Replies {
    static let anc = frame("aa 91 07 12 01 01 02 00 03 00")
    static let talkThru = frame("aa 91 07 12 01 00 02 00 03 01")
    static let battery90 = frame("aa 25 0d 01 00 00 5a 5a 00 00 00 00 00 00 00 00")
    static let lowVolumeEqOn = frame("aa 9e 02 02 01")
    static let deviceStatus = frame("aa 9b 03 02 01 00")
    static let balanceCentre = frame("aa a8 05 02 01 00 02 64")
}

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
    private(set) var requested: [Duration] = []

    init(immediateCount: Int = .max) {
        self.immediateCount = immediateCount
    }

    func sleep(_ duration: Duration) async throws {
        requested.append(duration)
        guard requested.count > immediateCount else { return }
        try await Task.sleep(for: .seconds(3600))
    }

    func requested(below limit: Duration) -> [Duration] {
        requested.filter { $0 < limit }
    }

    nonisolated var closure: Sleeper {
        { [self] duration in try await self.sleep(duration) }
    }
}
