import Testing

@testable import JBLProtocol

struct SettingTests {
    @Test func ambientLevelRejectsOutOfRange() {
        #expect(AmbientLevel(0) == nil)
        #expect(AmbientLevel(8) == nil)
        #expect(AmbientLevel(7)?.value == 7)
        #expect(AmbientLevel(1)?.value == 1)
    }

    @Test func balanceMapsOffsetToWire() {
        #expect(Balance(offset: -16)?.wire == 84)
        #expect(Balance(offset: 16)?.wire == 116)
        #expect(Balance(offset: 0)?.isOn == false)
        #expect(Balance(offset: 3)?.isOn == true)
    }

    @Test func balanceRejectsOutOfRangeOffset() {
        #expect(Balance(offset: -17) == nil)
        #expect(Balance(offset: 17) == nil)
    }

    @Test func balanceRejectsOutOfRangeWire() {
        #expect(Balance(wire: 83) == nil)
        #expect(Balance(wire: 117) == nil)
        #expect(Balance(wire: 100)?.offset == 0)
        #expect(Balance(wire: 96)?.offset == -4)
    }

    @Test func spatialModeRawValues() {
        #expect(SpatialMode.music.rawValue == 1)
        #expect(SpatialMode.movie.rawValue == 2)
        #expect(SpatialMode.game.rawValue == 3)
    }
}
