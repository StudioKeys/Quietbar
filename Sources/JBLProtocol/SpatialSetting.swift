public enum SpatialMode: UInt8, Sendable, Hashable, CaseIterable {
    case music = 1
    case movie = 2
    case game = 3
}

public struct SpatialSetting: Sendable, Hashable {
    public let isOn: Bool
    public let mode: SpatialMode

    public init(isOn: Bool, mode: SpatialMode) {
        self.isOn = isOn
        self.mode = mode
    }
}
