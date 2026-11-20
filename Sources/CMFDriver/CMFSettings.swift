import HeadphoneKit

enum CMFSetting {
    static let noiseMode: SettingID = "noiseMode"
    static let eqPreset: SettingID = "eqPreset"
    static let spatialSound: SettingID = "spatialSound"
    static let lowLag: SettingID = "lowLag"
    static let dualConnection: SettingID = "dualConnection"

    static let descriptors = [
        SettingDescriptor(
            id: noiseMode,
            title: "Noise control",
            kind: .choice(CMFNoiseMode.allCases.map(\.option), style: .menu),
            section: .noise,
            requiresExperimentalWrites: true
        ),
        SettingDescriptor(
            id: eqPreset,
            title: "EQ preset",
            symbol: "slider.vertical.3",
            kind: .choice(CMFEQPreset.allCases.map(\.option), style: .menu),
            section: .sound,
            requiresExperimentalWrites: true
        ),
        SettingDescriptor(
            id: spatialSound,
            title: "Spatial Audio",
            symbol: "dot.radiowaves.left.and.right",
            kind: .toggle,
            section: .sound,
            requiresExperimentalWrites: true
        ),
        SettingDescriptor(
            id: lowLag,
            title: "Low lag mode",
            symbol: "gamecontroller",
            kind: .toggle,
            section: .smart,
            requiresExperimentalWrites: true
        ),
        SettingDescriptor(
            id: dualConnection,
            title: "Dual connection",
            symbol: "laptopcomputer.and.iphone",
            kind: .toggle,
            section: .smart,
            appliesWithReconnect: true,
            requiresExperimentalWrites: true
        ),
    ]
}

enum CMFNoiseMode: UInt8, CaseIterable {
    case high = 1
    case medium = 2
    case low = 3
    case adaptive = 4
    case off = 5
    case transparency = 7

    var option: ChoiceOption {
        ChoiceOption(id: String(rawValue), title: title, symbol: symbol)
    }

    var title: String {
        switch self {
        case .high: "ANC High"
        case .medium: "ANC Mid"
        case .low: "ANC Low"
        case .adaptive: "Adaptive ANC"
        case .off: "Off"
        case .transparency: "Transparency"
        }
    }

    private var symbol: String {
        switch self {
        case .high, .medium, .low: "headphones"
        case .adaptive: "waveform.circle"
        case .off: "headphones.slash"
        case .transparency: "ear.badge.waveform"
        }
    }

    static func decode(_ raw: UInt8) -> CMFNoiseMode? {
        switch raw {
        case 7, 254: .transparency
        default: CMFNoiseMode(rawValue: raw)
        }
    }
}

enum CMFEQPreset: UInt8, CaseIterable {
    case balanced = 0
    case electronic = 2
    case pop = 3
    case rock = 6
    case classical = 8
    case vocals = 9

    var option: ChoiceOption {
        ChoiceOption(id: String(rawValue), title: title)
    }

    private var title: String {
        switch self {
        case .balanced: "Balanced"
        case .electronic: "Electronic"
        case .pop: "Pop"
        case .rock: "Rock"
        case .classical: "Classical"
        case .vocals: "Vocals"
        }
    }
}
