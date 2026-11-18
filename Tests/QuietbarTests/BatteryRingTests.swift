import HeadphoneKit
import Testing

@testable import Quietbar

struct BatteryRingTests {
    @Test(arguments: [
        (BatteryLevel(percent: 77, isCharging: false), BatteryRingStyle.normal),
        (BatteryLevel(percent: 21, isCharging: false), .normal),
        (BatteryLevel(percent: 20, isCharging: false), .low),
        (BatteryLevel(percent: 18, isCharging: false), .low),
        (BatteryLevel(percent: 18, isCharging: true), .charging),
        (BatteryLevel(percent: 90, isCharging: true), .charging),
    ])
    func ringStyleFollowsLevelAndCharging(level: BatteryLevel, style: BatteryRingStyle) {
        #expect(BatteryRingStyle.style(for: level) == style)
    }
}
