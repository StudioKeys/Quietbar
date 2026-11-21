import HeadphoneKit
import Testing

@testable import Quietbar

struct MenuBarIconTests {
    @Test(
        arguments: [
            ("anc", "headphones"), ("ambientAware", "ear.badge.waveform"), ("talkThru", "person.wave.2"),
            ("off", "headphones.slash"),
        ]
    )
    func iconFollowsNoiseModeSetting(mode: String, symbol: String) {
        let snapshot = Fixtures.snapshot(
            .connected,
            [.setting("noiseMode", .choice(mode)), .battery(Battery(percent: 90, isCharging: false))]
        )

        let icon = MenuBarIcon.make(for: snapshot, model: Fixtures.model)

        #expect(icon == MenuBarIcon(symbolName: symbol, isDimmed: false, batteryText: "90%"))
    }

    @Test(arguments: [ConnectionStatus.searching, .idle, .disconnectedByUser, .unavailable(.poweredOff)])
    func iconDimmedWithoutBatteryWhenNotConnected(status: ConnectionStatus) {
        let snapshot = Fixtures.snapshot(status, [.setting("noiseMode", .choice("talkThru"))])

        #expect(
            MenuBarIcon.make(for: snapshot, model: Fixtures.model)
                == MenuBarIcon(symbolName: "headphones", isDimmed: true, batteryText: nil)
        )
    }

    @Test(arguments: [ConnectionStatus.connected, .searching])
    func productGlyphIsCarriedInEveryState(status: ConnectionStatus) {
        let base = Fixtures.model
        let model = DeviceModel(
            name: base.name, nameFragment: base.nameFragment, link: base.link, settings: base.settings,
            glyph: "cmf.headphonePro")

        #expect(MenuBarIcon.make(for: Fixtures.snapshot(status), model: model).glyph == "cmf.headphonePro")
    }

    @Test func noiseModeStyleKeepsArtworkOnlyWhileDisconnected() {
        let base = Fixtures.model
        let model = DeviceModel(
            name: base.name, nameFragment: base.nameFragment, link: base.link, settings: base.settings,
            glyph: "cmf.headphonePro")
        let connected = MenuBarIcon.make(for: Fixtures.snapshot(.connected), model: model)
        let searching = MenuBarIcon.make(for: Fixtures.snapshot(.searching), model: model)

        #expect(connected.artworkGlyph(style: .product) == "cmf.headphonePro")
        #expect(connected.artworkGlyph(style: .noiseMode) == nil)
        #expect(searching.artworkGlyph(style: .noiseMode) == "cmf.headphonePro")
    }

    @Test func connectedWithUnknownModeShowsDefaultIcon() {
        #expect(
            MenuBarIcon.make(for: Fixtures.snapshot(), model: Fixtures.model)
                == MenuBarIcon(symbolName: "headphones", isDimmed: false, batteryText: nil)
        )
    }

    @Test(arguments: [ConnectionStatus.connected, .searching])
    func iconFallsBackToModelSymbol(status: ConnectionStatus) {
        let base = Fixtures.model
        let model = DeviceModel(
            name: base.name, nameFragment: base.nameFragment, link: base.link, settings: base.settings,
            symbol: "earbuds")

        #expect(MenuBarIcon.make(for: Fixtures.snapshot(status), model: model).symbolName == "earbuds")
    }

    @Test func menuBarItemsListKnownBuds() {
        let buds = Battery.buds(
            left: BatteryLevel(percent: 77, isCharging: false), right: BatteryLevel(percent: 72, isCharging: false),
            caseLevel: BatteryLevel(percent: 40, isCharging: false))!
        let snapshot = Fixtures.snapshot(.connected, [.battery(buds)])

        let icon = MenuBarIcon.make(for: snapshot, model: Fixtures.model)

        #expect(icon.batteryText == nil)
        #expect(icon.budLevels == [BudLevel(side: "L", percent: 77), BudLevel(side: "R", percent: 72)])
    }

    @Test func menuBarOmitsUnknownBud() {
        let buds = Battery.buds(left: nil, right: BatteryLevel(percent: 72, isCharging: false), caseLevel: nil)!

        let icon = MenuBarIcon.make(for: Fixtures.snapshot(.connected, [.battery(buds)]), model: Fixtures.model)

        #expect(icon.budLevels == [BudLevel(side: "R", percent: 72)])
    }
}
