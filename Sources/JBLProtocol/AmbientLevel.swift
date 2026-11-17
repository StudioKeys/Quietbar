public struct AmbientLevel: Sendable, Hashable {
    public static let range = 1...7

    public let value: UInt8

    public init?(_ value: Int) {
        guard Self.range.contains(value) else { return nil }
        self.value = UInt8(value)
    }
}
