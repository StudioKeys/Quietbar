import HeadphoneKit

enum BatteryRingStyle: Equatable {
    case normal
    case low
    case charging

    static let lowThreshold = 20

    static func style(for level: BatteryLevel) -> BatteryRingStyle {
        if level.isCharging { return .charging }
        return level.percent <= lowThreshold ? .low : .normal
    }
}
