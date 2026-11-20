import Foundation

public final class CMFSequence: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    public init() {}

    public func next() -> UInt8 {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        if value >= 254 {
            value = 0
        }
        return UInt8(value)
    }
}
