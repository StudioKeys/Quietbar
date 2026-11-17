import JBLDevice
import JBLProtocol

struct MenuBarIcon: Equatable {
    static let defaultSymbol = "headphones"

    let symbolName: String
    let isDimmed: Bool
    let batteryText: String?

    static func make(for snapshot: SessionSnapshot) -> MenuBarIcon {
        guard snapshot.status == .connected else {
            return MenuBarIcon(symbolName: defaultSymbol, isDimmed: true, batteryText: nil)
        }
        return MenuBarIcon(
            symbolName: symbol(for: snapshot.state.noiseMode),
            isDimmed: false,
            batteryText: snapshot.state.battery.map { "\($0.percent)%" }
        )
    }

    private static func symbol(for mode: NoiseMode?) -> String {
        switch mode {
        case .ambientAware: "ear.badge.waveform"
        case .talkThru: "person.wave.2"
        case .off: "headphones.slash"
        case .anc, nil: defaultSymbol
        }
    }
}
