public enum Command: Sendable, Hashable {
    case queryNoiseMode
    case setNoiseMode(NoiseMode)
    case queryAdvancedAnc
    case setAmbientLevel(AmbientLevel)
    case queryBattery
    case querySpatial
    case setSpatial(SpatialSetting)
    case queryLowVolumeEq
    case setLowVolumeEq(Bool)
    case queryEq
    case setEqPreset(EqPreset)
    case queryBalance
    case setBalance(Balance)
    case setAdaptiveAnc(Bool)
    case setLeakageCompensation(Bool)
    case querySmartAudioVideo
    case setSmartAudioVideo(SmartAudioVideoPreset)
    case setAutoPlayPause(Bool)
    case queryDeviceStatus

    public static let refreshAll: [Command] = [
        .queryNoiseMode, .queryAdvancedAnc, .queryBattery, .querySpatial, .queryLowVolumeEq, .queryEq, .queryBalance,
    ]

    public var frame: Frame {
        switch self {
        case .queryNoiseMode: Frame(command: Opcode.noise, payload: [0x11])
        case .setNoiseMode(let mode): Frame(command: Opcode.noise, payload: Self.noisePayload(mode))
        case .queryAdvancedAnc: Frame(command: Opcode.noise, payload: [0x21])
        case .setAmbientLevel(let level): Frame(command: Opcode.noise, payload: [0x20, 0xA1, level.value])
        case .queryBattery: Frame(command: Opcode.battery, payload: [0x00])
        case .querySpatial: Frame(command: Opcode.spatial, payload: [0x01])
        case .setSpatial(let setting):
            Frame(command: Opcode.spatial, payload: [0x00, setting.isOn.byte, setting.mode.rawValue])
        case .queryLowVolumeEq: Frame(command: Opcode.lowVolumeEq, payload: [0x01])
        case .setLowVolumeEq(let isOn): Frame(command: Opcode.lowVolumeEq, payload: [0x00, isOn.byte])
        case .queryEq: Frame(command: Opcode.eq, payload: [0x01, 0xFF])
        case .setEqPreset(let preset):
            Frame(command: Opcode.eq, payload: EqFrameBuilder.payload(for: preset), usesWideLength: true)
        case .queryBalance: Frame(command: Opcode.balance, payload: [0x01])
        case .setBalance(let balance):
            Frame(command: Opcode.balance, payload: [0x00, 0x01, balance.isOn.byte, 0x02, balance.wire])
        case .setAdaptiveAnc(let isOn): Frame(command: Opcode.noise, payload: [0x20, 0x01, isOn.byte])
        case .setLeakageCompensation(let isOn): Frame(command: Opcode.noise, payload: [0x20, 0x05, isOn.byte])
        case .querySmartAudioVideo: Frame(command: Opcode.smartAudioVideoGet, payload: [])
        case .setSmartAudioVideo(let preset): Frame(command: Opcode.smartAudioVideoSet, payload: preset.payload)
        case .setAutoPlayPause(let isOn): Frame(command: Opcode.autoPlayPause, payload: [isOn.byte])
        case .queryDeviceStatus: Frame(command: Opcode.deviceStatusGet, payload: [0x30])
        }
    }

    private static func noisePayload(_ mode: NoiseMode) -> [UInt8] {
        guard mode != .off else { return [0x13] }
        return [0x10, 0x01, (mode == .anc).byte, 0x02, (mode == .ambientAware).byte, 0x03, (mode == .talkThru).byte]
    }
}

enum Opcode {
    static let battery: UInt8 = 0x25
    static let noise: UInt8 = 0x91
    static let spatial: UInt8 = 0x9D
    static let lowVolumeEq: UInt8 = 0x9E
    static let eq: UInt8 = 0xA2
    static let balance: UInt8 = 0xA8
    static let smartAudioVideoSet: UInt8 = 0x81
    static let smartAudioVideoGet: UInt8 = 0x82
    static let smartAudioVideoStatus: UInt8 = 0x83
    static let autoPlayPause: UInt8 = 0x35
    static let deviceStatusGet: UInt8 = 0x21
    static let deviceStatusReply: UInt8 = 0x22
}

extension Bool {
    var byte: UInt8 { self ? 1 : 0 }
}
