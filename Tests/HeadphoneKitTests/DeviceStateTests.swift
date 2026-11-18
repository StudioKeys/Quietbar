import Testing

@testable import HeadphoneKit

struct DeviceStateTests {
    @Test func emptyStateKnowsNothing() {
        #expect(DeviceState.empty["noiseMode"] == nil)
        #expect(DeviceState.empty.battery == nil)
    }

    @Test func applyingUpdatesLeavesOriginalUnchanged() {
        let original = DeviceState.empty

        _ = original.applying([.setting("lowVolumeEq", .bool(true))])

        #expect(original == .empty)
    }

    @Test func applyingSeveralUpdatesSetsAll() {
        let state = DeviceState.empty.applying([
            .setting("adaptiveAnc", .bool(true)),
            .setting("ambientLevel", .level(7)),
            .battery(Battery(percent: 90, isCharging: false)),
        ])

        #expect(state["adaptiveAnc"] == .bool(true))
        #expect(state["ambientLevel"] == .level(7))
        #expect(state.battery == Battery(percent: 90, isCharging: false))
    }

    @Test func laterUpdateWins() {
        let state = DeviceState.empty
            .applying([.setting("eqPreset", .choice("jazz"))])
            .applying([.setting("eqPreset", .choice("studio"))])

        #expect(state["eqPreset"] == .choice("studio"))
    }

    @Test func emptyUpdateListReturnsEqualState() {
        let state = DeviceState.empty.applying([.setting("balance", .level(0))])

        #expect(state.applying([]) == state)
    }

    @Test func budsBatteryUsesLowerBud() {
        let battery = Battery.buds(
            left: BatteryLevel(percent: 77, isCharging: false), right: BatteryLevel(percent: 72, isCharging: false),
            caseLevel: BatteryLevel(percent: 40, isCharging: true))

        #expect(battery?.percent == 72)
        #expect(battery?.isCharging == false)
        #expect(battery?.caseLevel == BatteryLevel(percent: 40, isCharging: true))
    }

    @Test func unknownBudIgnored() {
        let battery = Battery.buds(left: nil, right: BatteryLevel(percent: 72, isCharging: false), caseLevel: nil)

        #expect(battery?.percent == 72)
        #expect(battery?.left == nil)
    }

    @Test func noBudsKnownIsNil() {
        #expect(Battery.buds(left: nil, right: nil, caseLevel: BatteryLevel(percent: 40, isCharging: false)) == nil)
    }

    @Test func chargingIfAnyBudCharges() {
        let battery = Battery.buds(
            left: BatteryLevel(percent: 77, isCharging: true), right: BatteryLevel(percent: 72, isCharging: false),
            caseLevel: nil)

        #expect(battery?.isCharging == true)
        #expect(battery?.hasComponents == true)
        #expect(Battery(percent: 90, isCharging: false).hasComponents == false)
    }
}
