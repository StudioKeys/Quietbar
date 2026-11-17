public enum EqPreset: Sendable, Hashable, CaseIterable {
    case jazz
    case vocal
    case bass
    case club
    case studio
    case extremeBass

    public static let bandFrequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    public init?(id: UInt8) {
        guard let preset = Self.allCases.first(where: { $0.id == id }) else { return nil }
        self = preset
    }

    public var id: UInt8 {
        switch self {
        case .jazz: 0x01
        case .vocal: 0x02
        case .bass: 0x03
        case .club: 0x06
        case .studio: 0x07
        case .extremeBass: 0x09
        }
    }

    public var displayName: String {
        switch self {
        case .jazz: "Jazz"
        case .vocal: "Vocal"
        case .bass: "Bass"
        case .club: "Club"
        case .studio: "Studio"
        case .extremeBass: "Extreme Bass"
        }
    }

    public var gains: [Float] {
        switch self {
        case .jazz: [4, 3, 1, 2.5, -1.5, -1.5, 0, 1, 3, 4]
        case .vocal: [-1.5, -3, -3, 1, 3.5, 3.5, 3, 1.5, 0, -1.5]
        case .bass: [4, 4, 3, 2.5, 0.5, 0, 0, 0, 0, 0]
        case .club: [2, 1.5, 1, 0, 0, 0, 0, 1, 1, 2]
        case .studio: [-2, -1, -1, -0.5, 0, 0, 0, 0, 0, 0]
        case .extremeBass: [4, 4.5, 4.5, 3.5, -1, 0, 0, 2, 2, 0]
        }
    }
}

public enum EqSelection: Sendable, Hashable {
    case preset(EqPreset)
    case custom(UInt8)
}
