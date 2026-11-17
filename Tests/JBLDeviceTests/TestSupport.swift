import Foundation
import JBLDevice
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
