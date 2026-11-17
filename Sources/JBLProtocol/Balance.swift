public struct Balance: Sendable, Hashable {
    public static let range = -16...16
    static let centreWire = 100

    public let offset: Int

    public init?(offset: Int) {
        guard Self.range.contains(offset) else { return nil }
        self.offset = offset
    }

    public init?(wire: UInt8) {
        self.init(offset: Int(wire) - Self.centreWire)
    }

    public var wire: UInt8 { UInt8(Self.centreWire + offset) }

    public var isOn: Bool { offset != 0 }
}
