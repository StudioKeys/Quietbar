import HeadphoneKit
import JBLProtocol
import Testing

@testable import Quietbar

struct MenuBarIconTests {
    @Test(
        arguments: [
            (NoiseMode.anc, "headphones"),
            (.ambientAware, "ear.badge.waveform"),
            (.talkThru, "person.wave.2"),
            (.off, "headphones.slash"),
        ]
    )
    func iconFollowsNoiseMode(mode: NoiseMode, symbol: String) {
        let icon = MenuBarIcon.make(for: snapshot(noiseMode: mode, battery: 90))

        #expect(icon == MenuBarIcon(symbolName: symbol, isDimmed: false, batteryText: "90%"))
    }

    @Test(arguments: [ConnectionStatus.searching, .idle, .disconnectedByUser, .unavailable(.poweredOff)])
    func iconDimmedWithoutBatteryWhenNotConnected(status: ConnectionStatus) {
        let icon = MenuBarIcon.make(for: snapshot(status, noiseMode: .talkThru, battery: 90))

        #expect(icon == MenuBarIcon(symbolName: "headphones", isDimmed: true, batteryText: nil))
    }

    @Test func connectedWithUnknownStateShowsPlainIcon() {
        let icon = MenuBarIcon.make(for: snapshot())

        #expect(icon == MenuBarIcon(symbolName: "headphones", isDimmed: false, batteryText: nil))
    }
}
