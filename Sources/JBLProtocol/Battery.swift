public struct Battery: Sendable, Hashable {
    public let percent: Int
    public let isCharging: Bool

    public init(percent: Int, isCharging: Bool) {
        self.percent = percent
        self.isCharging = isCharging
    }
}
