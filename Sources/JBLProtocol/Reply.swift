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
}
