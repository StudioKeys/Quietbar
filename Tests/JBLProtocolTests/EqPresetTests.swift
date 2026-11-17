import Testing

@testable import JBLProtocol

struct EqPresetTests {
    @Test func eqPresetIdsMatchHeadset() {
        #expect(EqPreset.jazz.id == 0x01)
        #expect(EqPreset.vocal.id == 0x02)
        #expect(EqPreset.bass.id == 0x03)
        #expect(EqPreset.club.id == 0x06)
        #expect(EqPreset.studio.id == 0x07)
        #expect(EqPreset.extremeBass.id == 0x09)
    }

    @Test(
        arguments: [
            (EqPreset.jazz, [4, 3, 1, 2.5, -1.5, -1.5, 0, 1, 3, 4] as [Float]),
            (.vocal, [-1.5, -3, -3, 1, 3.5, 3.5, 3, 1.5, 0, -1.5]),
            (.bass, [4, 4, 3, 2.5, 0.5, 0, 0, 0, 0, 0]),
            (.club, [2, 1.5, 1, 0, 0, 0, 0, 1, 1, 2]),
            (.studio, [-2, -1, -1, -0.5, 0, 0, 0, 0, 0, 0]),
            (.extremeBass, [4, 4.5, 4.5, 3.5, -1, 0, 0, 2, 2, 0]),
        ]
    )
    func eqPresetGainsMatchProtocolTable(preset: EqPreset, gains: [Float]) {
        #expect(preset.gains == gains)
    }

    @Test func bandFrequenciesCoverTenBands() {
        #expect(EqPreset.bandFrequencies == [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000])
    }

    @Test func presetResolvesFromId() {
        #expect(EqPreset(id: 0x07) == .studio)
        #expect(EqPreset(id: 0xCA) == nil)
    }

    @Test func displayNamesAreHumanReadable() {
        #expect(EqPreset.extremeBass.displayName == "Extreme Bass")
        #expect(EqPreset.studio.displayName == "Studio")
    }
}
