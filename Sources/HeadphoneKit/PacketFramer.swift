import Foundation

public protocol PacketFramer: Sendable {
    mutating func push(_ chunk: Data) -> [Data]
}

public struct PassthroughFramer: PacketFramer {
    public init() {}

    public mutating func push(_ chunk: Data) -> [Data] { [chunk] }
}
