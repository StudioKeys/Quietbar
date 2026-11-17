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
}
