public enum ReplyKind: Sendable, Hashable, CaseIterable {
    case noiseMode
    case ambientLevel
    case battery
    case spatial
    case lowVolumeEq
    case eq
    case balance
    case smartAudioVideo
    case autoPlayPause

    public var query: Command {
        switch self {
        case .noiseMode: .queryNoiseMode
        case .ambientLevel: .queryAdvancedAnc
        case .battery: .queryBattery
        case .spatial: .querySpatial
        case .lowVolumeEq: .queryLowVolumeEq
        case .eq: .queryEq
        case .balance: .queryBalance
        case .smartAudioVideo: .querySmartAudioVideo
        case .autoPlayPause: .queryDeviceStatus
        }
    }
}

public enum Reply: Sendable, Hashable {
    case noiseMode(NoiseMode)
    case ambientLevel(AmbientLevel)
    case battery(Battery)
    case spatial(SpatialSetting)
    case lowVolumeEq(Bool)
    case eq(EqSelection)
    case balance(Balance)
    case unknown(Frame)

    public init(frame: Frame) {
        self = ReplyDecoder.decode(frame) ?? .unknown(frame)
    }

    public var kind: ReplyKind? {
        switch self {
        case .noiseMode: .noiseMode
        case .ambientLevel: .ambientLevel
        case .battery: .battery
        case .spatial: .spatial
        case .lowVolumeEq: .lowVolumeEq
        case .eq: .eq
        case .balance: .balance
        case .unknown: nil
        }
    }
}

extension Command {
    public var expectedReply: ReplyKind {
        switch self {
        case .queryNoiseMode, .setNoiseMode: .noiseMode
        case .queryAdvancedAnc, .setAmbientLevel, .setAdaptiveAnc, .setLeakageCompensation: .ambientLevel
        case .querySmartAudioVideo, .setSmartAudioVideo: .smartAudioVideo
        case .setAutoPlayPause, .queryDeviceStatus: .autoPlayPause
        case .queryBattery: .battery
        case .querySpatial, .setSpatial: .spatial
        case .queryLowVolumeEq, .setLowVolumeEq: .lowVolumeEq
        case .queryEq, .setEqPreset: .eq
        case .queryBalance, .setBalance: .balance
        }
    }
}
