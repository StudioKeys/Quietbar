import CMFProtocol
import HeadphoneKit

enum CMFSetting {
    static let noiseMode: SettingID = "noiseMode"
    static let ancLevel: SettingID = "ancLevel"
    static let spatialMode: SettingID = "spatialMode"
    static let eqPreset: SettingID = "eqPreset"
    static let bass: SettingID = "eqBass"
    static let mid: SettingID = "eqMid"
    static let treble: SettingID = "eqTreble"
    static let lowLag: SettingID = "lowLag"
    static let dualConnection: SettingID = "dualConnection"

    static let customPreset = String(CMFEQPreset.custom.rawValue)
    private static let isCustom = Condition.equals(eqPreset, .choice(customPreset))

    static let descriptors = [
        SettingDescriptor(
            id: noiseMode, title: "Noise Control",
            kind: .choice(CMFNoiseMode.allCases.map(\.option), style: .modeButtons), section: .noise
        ),
        SettingDescriptor(
            id: ancLevel, title: "Noise Cancellation level",
            kind: .choice(CMFANCLevel.displayOrder.map(\.option), style: .levelBars), section: .noise,
            visibleWhen: .equals(noiseMode, .choice(CMFNoiseMode.anc.id))
        ),
        SettingDescriptor(
            id: spatialMode, title: "Spatial Audio",
            kind: .choice(CMFSpatialMode.allCases.map(\.option), style: .modeButtons), section: .spatial
        ),
        SettingDescriptor(
            id: eqPreset, title: "Equaliser", symbol: "slider.vertical.3",
            kind: .choice(CMFEQPreset.allCases.map(\.option), style: .pills), section: .sound
        ),
        SettingDescriptor(
            id: bass, title: "Bass", symbol: "speaker.wave.3",
            kind: .level(CMFCustomEQ.gainRange, style: .dial), section: .sound, visibleWhen: isCustom
        ),
        SettingDescriptor(
            id: mid, title: "Mid", symbol: "waveform",
            kind: .level(CMFCustomEQ.gainRange, style: .dial), section: .sound, visibleWhen: isCustom
        ),
        SettingDescriptor(
            id: treble, title: "Treble", symbol: "sparkles",
            kind: .level(CMFCustomEQ.gainRange, style: .dial), section: .sound, visibleWhen: isCustom
        ),
        SettingDescriptor(
            id: lowLag, title: "Low Lag Mode", symbol: "gamecontroller", kind: .toggle, section: .smart
        ),
        SettingDescriptor(
            id: dualConnection, title: "Dual Connection", symbol: "laptopcomputer.and.iphone", kind: .toggle,
            section: .smart, appliesWithReconnect: true
        ),
    ]

    static func band(for id: SettingID) -> CMFCustomEQ.Band? {
        switch id {
        case bass: .bass
        case mid: .mid
        case treble: .treble
        default: nil
        }
    }
}

enum CMFNoiseMode: String, CaseIterable {
    case anc
    case transparency
    case off

    var id: String { rawValue }

    var option: ChoiceOption {
        switch self {
        case .anc: ChoiceOption(id: id, title: "Noise Cancellation", symbol: "circle.circle")
        case .transparency: ChoiceOption(id: id, title: "Transparency", symbol: "circle.dotted.circle")
        case .off: ChoiceOption(id: id, title: "Off", symbol: "circle.slash")
        }
    }
}

enum CMFANCLevel: UInt8, CaseIterable {
    case high = 1
    case mid = 2
    case low = 3
    case adaptive = 4

    static let displayOrder: [CMFANCLevel] = [.low, .mid, .high, .adaptive]

    var option: ChoiceOption {
        switch self {
        case .high: ChoiceOption(id: String(rawValue), title: "High")
        case .mid: ChoiceOption(id: String(rawValue), title: "Mid")
        case .low: ChoiceOption(id: String(rawValue), title: "Low")
        case .adaptive: ChoiceOption(id: String(rawValue), title: "Adaptive")
        }
    }
}

enum CMFNoiseValue {
    static let off: UInt8 = 5
    static let transparency: UInt8 = 7
    static let transparencyAlias: UInt8 = 254
}

enum CMFSpatialMode: UInt8, CaseIterable {
    case concert = 2
    case cinema = 3
    case off = 0

    var option: ChoiceOption {
        switch self {
        case .concert: ChoiceOption(id: String(rawValue), title: "Concert", symbol: "music.mic")
        case .cinema: ChoiceOption(id: String(rawValue), title: "Cinema", symbol: "film")
        case .off: ChoiceOption(id: String(rawValue), title: "Off", symbol: "speaker.slash")
        }
    }
}

enum CMFEQPreset: UInt8, CaseIterable {
    case pop = 3
    case rock = 1
    case electronic = 2
    case vocals = 4
    case classical = 5
    case custom = 6

    var option: ChoiceOption {
        switch self {
        case .pop: ChoiceOption(id: String(rawValue), title: "Pop", symbol: "music.note")
        case .rock: ChoiceOption(id: String(rawValue), title: "Rock", symbol: "guitars")
        case .electronic: ChoiceOption(id: String(rawValue), title: "Electronic", symbol: "waveform.path")
        case .vocals: ChoiceOption(id: String(rawValue), title: "Vocals", symbol: "music.mic")
        case .classical: ChoiceOption(id: String(rawValue), title: "Classical", symbol: "music.quarternote.3")
        case .custom: ChoiceOption(id: String(rawValue), title: "Custom", symbol: "slider.horizontal.3")
        }
    }
}
