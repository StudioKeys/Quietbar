import HeadphoneKit

struct MenuBarIcon: Equatable {
    static let defaultSymbol = "headphones"

    let symbolName: String
    let isDimmed: Bool
    let batteryText: String?

    static func make(for snapshot: DeviceSnapshot, model: DeviceModel) -> MenuBarIcon {
        guard snapshot.status == .connected else {
            return MenuBarIcon(symbolName: defaultSymbol, isDimmed: true, batteryText: nil)
        }
        return MenuBarIcon(
            symbolName: modeSymbol(in: snapshot.state, model: model) ?? defaultSymbol,
            isDimmed: false,
            batteryText: snapshot.state.battery.map { "\($0.percent)%" }
        )
    }

    private static func modeSymbol(in state: DeviceState, model: DeviceModel) -> String? {
        for descriptor in model.settings {
            guard case .choice(let options, style: .modeButtons) = descriptor.kind,
                case .choice(let selected) = state[descriptor.id]
            else { continue }
            return options.first { $0.id == selected }?.symbol
        }
        return nil
    }
}
