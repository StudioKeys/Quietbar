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
    static let autoPlayPause: SettingID = "autoPlayPause"

    static let customEq = "custom"
    static let spatialOff = ChoiceOption(id: "off", title: "Off", symbol: "speaker.slash")

    static let descriptors: [SettingDescriptor] = [
        SettingDescriptor(
            id: noiseMode,
            title: "Noise control",
            kind: .choice(NoiseMode.allCases.map(\.option), style: .modeButtons),
            section: .noise
        ),
        SettingDescriptor(
            id: adaptiveAnc, title: "Adaptive ANC", symbol: "waveform.circle", kind: .toggle, section: .noise,
            visibleWhen: .equals(noiseMode, .choice(NoiseMode.anc.id))
        ),
        SettingDescriptor(
            id: leakageCompensation, title: "Leakage compensation", symbol: "ear.badge.checkmark", kind: .toggle,
            section: .noise,
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
            id: spatialSound, title: "Spatial Sound",
            kind: .choice([spatialOff] + SpatialMode.allCases.map(\.option), style: .modeButtons), section: .spatial
        ),
        SettingDescriptor(
            id: lowVolumeEq, title: "Low Volume EQ", symbol: "speaker.wave.1", kind: .toggle, section: .sound
        ),
        SettingDescriptor(
            id: balance, title: "Balance", symbol: "arrow.left.and.right",
            kind: .level(Balance.range, style: .balance), section: .sound
        ),
        SettingDescriptor(
            id: smartAudioVideo, title: "Smart Audio & Video", symbol: "play.tv",
            kind: .choice(SmartMode.allCases.map(\.option), style: .labeledSegmented), section: .smart,
            appliesWithReconnect: true
        ),
        SettingDescriptor(
            id: autoPlayPause, title: "Auto play & pause", symbol: "playpause", kind: .toggle, section: .smart
        ),
    ]
}

enum SmartMode: String, CaseIterable {
    case off
    case audio
    case video

    init(preset: SmartAudioVideoPreset) {
        switch preset {
        case .normal: self = .off
        case .audio: self = .audio
        case .video: self = .video
        }
    }

    var preset: SmartAudioVideoPreset {
        switch self {
        case .off: .normal
        case .audio: .audio
        case .video: .video
        }
    }

    var option: ChoiceOption {
        switch self {
        case .off: ChoiceOption(id: rawValue, title: "Off")
        case .audio: ChoiceOption(id: rawValue, title: "Audio")
        case .video: ChoiceOption(id: rawValue, title: "Video")
        }
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
        switch self {
        case .music: ChoiceOption(id: settingID, title: "Music", symbol: "music.note")
        case .movie: ChoiceOption(id: settingID, title: "Movie", symbol: "film")
        case .game: ChoiceOption(id: settingID, title: "Game", symbol: "gamecontroller")
        }
    }

    init?(settingID: String) {
        guard let mode = Self.allCases.first(where: { $0.settingID == settingID }) else { return nil }
        self = mode
    }
}
