import HeadphoneKit

enum MotoSetting {
    static let noiseMode: SettingID = "noiseMode"
    static let eqPreset: SettingID = "eqPreset"
    static let spatialSound: SettingID = "spatialSound"
    static let hiRes: SettingID = "hiRes"
    static let volumeBoost: SettingID = "volumeBoost"
    static let gameMode: SettingID = "gameMode"
    static let inEarDetection: SettingID = "inEarDetection"
    static let dualConnection: SettingID = "dualConnection"

    static let descriptors: [SettingDescriptor] = [
        SettingDescriptor(
            id: noiseMode, title: "Noise control",
            kind: .choice(NoiseControl.allCases.map(\.option), style: .modeButtons), section: .noise
        ),
        SettingDescriptor(
            id: eqPreset, title: "EQ preset", symbol: "slider.vertical.3",
            kind: .choice(EqPreset.allCases.map(\.option), style: .pills), section: .sound
        ),
        SettingDescriptor(
            id: spatialSound, title: "Spatial Sound", symbol: "dot.radiowaves.left.and.right", kind: .toggle,
            section: .sound
        ),
        SettingDescriptor(
            id: hiRes, title: "Hi-Res Audio", symbol: "waveform.badge.plus", kind: .toggle, section: .sound,
            appliesWithReconnect: true
        ),
        SettingDescriptor(
            id: volumeBoost, title: "Volume Boost", symbol: "speaker.plus", kind: .toggle, section: .sound
        ),
        SettingDescriptor(id: gameMode, title: "Game Mode", symbol: "gamecontroller", kind: .toggle, section: .smart),
        SettingDescriptor(
            id: inEarDetection, title: "In-ear detection", symbol: "ear", kind: .toggle, section: .smart
        ),
        SettingDescriptor(
            id: dualConnection, title: "Dual connection", symbol: "laptopcomputer.and.iphone", kind: .toggle,
            section: .smart
        ),
    ]
}

enum NoiseControl: String, CaseIterable {
    case anc
    case adaptive
    case transparency
    case off

    var option: ChoiceOption {
        switch self {
        case .anc: ChoiceOption(id: rawValue, title: "Noise Cancellation", symbol: "headphones")
        case .adaptive: ChoiceOption(id: rawValue, title: "Adaptive", symbol: "waveform.circle")
        case .transparency: ChoiceOption(id: rawValue, title: "Transparency", symbol: "ear.badge.waveform")
        case .off: ChoiceOption(id: rawValue, title: "Off", symbol: "headphones.slash")
        }
    }

    var payload: [UInt8] {
        switch self {
        case .anc: [0x01, 0x03]
        case .adaptive: [0x01, 0x01]
        case .transparency: [0x02, 0x00]
        case .off: [0x00, 0x00]
        }
    }

    init?(payload: [UInt8]) {
        guard payload.count >= 2 else { return nil }
        switch (payload[0], payload[1]) {
        case (0x00, _): self = .off
        case (0x02, _): self = .transparency
        case (0x01, 0x01): self = .adaptive
        case (0x01, _): self = .anc
        default: return nil
        }
    }
}

enum EqPreset: UInt8, CaseIterable {
    case brilliantTreble = 1
    case bassBoost = 2
    case vocalBoost = 3
    case flat = 4
    case custom = 63

    var option: ChoiceOption {
        ChoiceOption(id: String(rawValue), title: title, symbol: symbol)
    }

    private var symbol: String {
        switch self {
        case .brilliantTreble: "sparkles"
        case .bassBoost: "speaker.wave.3"
        case .vocalBoost: "music.mic"
        case .flat: "equal"
        case .custom: "slider.horizontal.3"
        }
    }

    private var title: String {
        switch self {
        case .brilliantTreble: "Treble Boost"
        case .bassBoost: "Bass Boost"
        case .vocalBoost: "Vocal Boost"
        case .flat: "Flat"
        case .custom: "Custom"
        }
    }
}
