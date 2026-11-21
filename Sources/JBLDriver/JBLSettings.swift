import HeadphoneKit
import JBLProtocol

enum JBLSetting {
    static let noiseMode: SettingID = "noiseMode"
    static let adaptiveAnc: SettingID = "adaptiveAnc"
    static let leakageCompensation: SettingID = "leakageCompensation"
    static let ambientLevel: SettingID = "ambientLevel"
    static let eqPreset: SettingID = "eqPreset"
    static let spatialSound: SettingID = "spatialSound"
    static let spatialMode: SettingID = "spatialMode"
    static let lowVolumeEq: SettingID = "lowVolumeEq"
    static let balance: SettingID = "balance"
    static let smartAudioVideo: SettingID = "smartAudioVideo"
    static let smartAudioVideoMode: SettingID = "smartAudioVideoMode"
    static let autoPlayPause: SettingID = "autoPlayPause"

    static let customEq = "custom"

    static let descriptors: [SettingDescriptor] = [
        SettingDescriptor(
            id: noiseMode,
            title: "Noise control",
            kind: .choice(NoiseMode.allCases.map(\.option), style: .modeButtons),
            section: .noise
        ),
        SettingDescriptor(
            id: adaptiveAnc, title: "Adaptive ANC", kind: .toggle, section: .noise,
            visibleWhen: .equals(noiseMode, .choice(NoiseMode.anc.id))
        ),
        SettingDescriptor(
            id: leakageCompensation, title: "Leakage compensation", kind: .toggle, section: .noise,
            visibleWhen: .equals(noiseMode, .choice(NoiseMode.anc.id))
        ),
        SettingDescriptor(
            id: ambientLevel, title: "Ambient level", kind: .level(AmbientLevel.range, style: .slider), section: .noise,
            visibleWhen: .equals(noiseMode, .choice(NoiseMode.ambientAware.id))
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
            id: spatialMode, title: "Spatial mode",
            kind: .choice(SpatialMode.allCases.map(\.option), style: .segmented),
            section: .sound, visibleWhen: .equals(spatialSound, .bool(true))
        ),
        SettingDescriptor(
            id: lowVolumeEq, title: "Low Volume EQ", symbol: "speaker.wave.1", kind: .toggle, section: .sound
        ),
        SettingDescriptor(
            id: balance, title: "Balance", symbol: "arrow.left.and.right",
            kind: .level(Balance.range, style: .balance), section: .sound
        ),
        SettingDescriptor(
            id: smartAudioVideo, title: "Smart Audio & Video", symbol: "play.tv", kind: .toggle, section: .smart,
            appliesWithReconnect: true
        ),
        SettingDescriptor(
            id: smartAudioVideoMode, title: "Smart Audio & Video mode",
            kind: .choice(SmartMode.allCases.map(\.option), style: .segmented), section: .smart,
            visibleWhen: .equals(smartAudioVideo, .bool(true)), appliesWithReconnect: true
        ),
        SettingDescriptor(
            id: autoPlayPause, title: "Auto play & pause", symbol: "playpause", kind: .toggle, section: .smart
        ),
    ]
}

enum SmartMode: String, CaseIterable {
    case audio
    case video

    var preset: SmartAudioVideoPreset { self == .audio ? .audio : .video }

    var option: ChoiceOption {
        ChoiceOption(id: rawValue, title: self == .audio ? "Audio Mode" : "Video Mode")
    }
}

extension NoiseMode {
    var id: String {
        switch self {
        case .anc: "anc"
        case .ambientAware: "ambientAware"
        case .talkThru: "talkThru"
        case .off: "off"
        }
    }

    var option: ChoiceOption {
        switch self {
        case .anc: ChoiceOption(id: id, title: "Noise Cancellation", symbol: "headphones")
        case .ambientAware: ChoiceOption(id: id, title: "Ambient", symbol: "ear.badge.waveform")
        case .talkThru: ChoiceOption(id: id, title: "Talk-Thru", symbol: "person.wave.2")
        case .off: ChoiceOption(id: id, title: "Off", symbol: "headphones.slash")
        }
    }

    init?(id: String) {
        guard let mode = Self.allCases.first(where: { $0.id == id }) else { return nil }
        self = mode
    }
}

extension EqPreset {
    var settingID: String {
        switch self {
        case .jazz: "jazz"
        case .vocal: "vocal"
        case .bass: "bass"
        case .club: "club"
        case .studio: "studio"
        case .extremeBass: "extremeBass"
        }
    }

    var option: ChoiceOption { ChoiceOption(id: settingID, title: displayName, symbol: symbol) }

    private var symbol: String {
        switch self {
        case .jazz: "music.quarternote.3"
        case .vocal: "music.mic"
        case .bass: "speaker.wave.2"
        case .club: "figure.dance"
        case .studio: "waveform"
        case .extremeBass: "speaker.wave.3"
        }
    }

    init?(settingID: String) {
        guard let preset = Self.allCases.first(where: { $0.settingID == settingID }) else { return nil }
        self = preset
    }
}

extension SpatialMode {
    var settingID: String {
        switch self {
        case .music: "music"
        case .movie: "movie"
        case .game: "game"
        }
    }

    var option: ChoiceOption {
        ChoiceOption(id: settingID, title: settingID.prefix(1).uppercased() + settingID.dropFirst())
    }

    init?(settingID: String) {
        guard let mode = Self.allCases.first(where: { $0.settingID == settingID }) else { return nil }
        self = mode
    }
}
