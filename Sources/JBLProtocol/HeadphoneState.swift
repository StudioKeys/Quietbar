public struct HeadphoneState: Sendable, Hashable {
    public static let empty = HeadphoneState()

    public let noiseMode: NoiseMode?
    public let ambientLevel: AmbientLevel?
    public let battery: Battery?
    public let spatial: SpatialSetting?
    public let lowVolumeEq: Bool?
    public let eq: EqSelection?
    public let balance: Balance?

    init(
        noiseMode: NoiseMode? = nil,
        ambientLevel: AmbientLevel? = nil,
        battery: Battery? = nil,
        spatial: SpatialSetting? = nil,
        lowVolumeEq: Bool? = nil,
        eq: EqSelection? = nil,
        balance: Balance? = nil
    ) {
        self.noiseMode = noiseMode
        self.ambientLevel = ambientLevel
        self.battery = battery
        self.spatial = spatial
        self.lowVolumeEq = lowVolumeEq
        self.eq = eq
        self.balance = balance
    }

    public func applying(_ reply: Reply) -> HeadphoneState {
        switch reply {
        case .noiseMode(let value): copy(noiseMode: value)
        case .ambientLevel(let value): copy(ambientLevel: value)
        case .battery(let value): copy(battery: value)
        case .spatial(let value): copy(spatial: value)
        case .lowVolumeEq(let value): copy(lowVolumeEq: value)
        case .eq(let value): copy(eq: value)
        case .balance(let value): copy(balance: value)
        case .unknown: self
        }
    }

    private func copy(
        noiseMode: NoiseMode? = nil,
        ambientLevel: AmbientLevel? = nil,
        battery: Battery? = nil,
        spatial: SpatialSetting? = nil,
        lowVolumeEq: Bool? = nil,
        eq: EqSelection? = nil,
        balance: Balance? = nil
    ) -> HeadphoneState {
        HeadphoneState(
            noiseMode: noiseMode ?? self.noiseMode,
            ambientLevel: ambientLevel ?? self.ambientLevel,
            battery: battery ?? self.battery,
            spatial: spatial ?? self.spatial,
            lowVolumeEq: lowVolumeEq ?? self.lowVolumeEq,
            eq: eq ?? self.eq,
            balance: balance ?? self.balance
        )
    }
}
