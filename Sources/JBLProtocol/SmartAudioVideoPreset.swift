public enum SmartAudioVideoPreset: Sendable, Hashable, CaseIterable {
    case normal
    case audio
    case video

    private static let unusedLatency: [UInt8] = [0xFF, 0xFF]

    public init?(payload: [UInt8]) {
        guard payload.count >= 6 else { return nil }
        let fields = stride(from: 0, to: 6, by: 2).map { UInt16(payload[$0]) | UInt16(payload[$0 + 1]) << 8 }
        guard let preset = Self.allCases.first(where: { $0.fields == fields }) else { return nil }
        self = preset
    }

    var fields: [UInt16] {
        switch self {
        case .normal: [256, 46, 180]
        case .audio: [256, 53, 150]
        case .video: [197, 46, 100]
        }
    }

    var payload: [UInt8] {
        fields.flatMap { [UInt8(truncatingIfNeeded: $0), UInt8(truncatingIfNeeded: $0 >> 8)] } + Self.unusedLatency
    }
}
