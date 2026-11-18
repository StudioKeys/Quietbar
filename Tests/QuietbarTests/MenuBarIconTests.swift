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

    @Test func connectedWithUnknownModeShowsDefaultIcon() {
        #expect(
            MenuBarIcon.make(for: Fixtures.snapshot(), model: Fixtures.model)
                == MenuBarIcon(symbolName: "headphones", isDimmed: false, batteryText: nil)
        )
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
