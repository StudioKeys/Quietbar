enum EqFrameBuilder {
    private static let header: [UInt8] = [0x03]
    private static let reserved: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x30] + [UInt8](repeating: 0, count: 8)
    private static let bandMarker: [UInt8] = [0x0A, 0x01]
    private static let terminator: [UInt8] = [0x0A]

    static func payload(for preset: EqPreset) -> [UInt8] {
        let bands = zip(preset.gains, EqPreset.bandFrequencies).flatMap { gain, frequency in
            bandMarker + littleEndianBytes(gain) + littleEndianBytes(frequency)
        }
        return header + [preset.id] + reserved + bands + terminator
    }

    private static func littleEndianBytes(_ value: Float) -> [UInt8] {
        withUnsafeBytes(of: value.bitPattern.littleEndian) { Array($0) }
    }
}
