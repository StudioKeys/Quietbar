import Testing

@testable import JBLProtocol

struct HeadphoneStateTests {
    @Test func emptyStateHasNoSettings() {
        let state = HeadphoneState.empty

        #expect(state.noiseMode == nil)
        #expect(state.battery == nil)
        #expect(state.balance == nil)
    }

    @Test func applyingBatteryChangesOnlyBattery() {
        let before = HeadphoneState.empty.applying(.noiseMode(.anc))

        let after = before.applying(.battery(Battery(percent: 80, isCharging: false)))

        #expect(after.noiseMode == .anc)
        #expect(after.battery == Battery(percent: 80, isCharging: false))
    }

    @Test func applyingUnknownReturnsEqualState() {
        let before = HeadphoneState.empty.applying(.lowVolumeEq(true))

        let after = before.applying(.unknown(Frame(command: 0x9B, payload: [0x02])))

        #expect(after == before)
    }

    @Test func applyingLeavesOriginalUnchanged() {
        let original = HeadphoneState.empty

        _ = original.applying(.noiseMode(.talkThru))

        #expect(original == .empty)
    }

    @Test func applyingEveryReplyKindSetsItsField() {
        let state = HeadphoneState.empty
            .applying(.noiseMode(.ambientAware))
            .applying(.ambientLevel(AmbientLevel(4)!))
            .applying(.battery(Battery(percent: 55, isCharging: true)))
            .applying(.spatial(SpatialSetting(isOn: true, mode: .game)))
            .applying(.lowVolumeEq(false))
            .applying(.eq(.preset(.club)))
            .applying(.balance(Balance(offset: 5)!))

        #expect(state.noiseMode == .ambientAware)
        #expect(state.ambientLevel == AmbientLevel(4))
        #expect(state.battery == Battery(percent: 55, isCharging: true))
        #expect(state.spatial == SpatialSetting(isOn: true, mode: .game))
        #expect(state.lowVolumeEq == false)
        #expect(state.eq == .preset(.club))
        #expect(state.balance == Balance(offset: 5))
    }

    @Test func laterReplyOverridesEarlierValue() {
        let state = HeadphoneState.empty.applying(.eq(.preset(.jazz))).applying(.eq(.custom(0xC9)))

        #expect(state.eq == .custom(0xC9))
    }
}
