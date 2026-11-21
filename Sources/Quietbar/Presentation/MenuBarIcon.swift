import HeadphoneKit

struct BudLevel: Equatable {
    let side: String
    let percent: Int
}

enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    static let key = "menuBarIconStyle"

    case product
    case noiseMode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .product: "Headphones"
        case .noiseMode: "Noise mode"
        }
    }
}

struct MenuBarIcon: Equatable {
    static let defaultSymbol = "headphones"

    let symbolName: String
    let isDimmed: Bool
    let batteryText: String?
    var budLevels: [BudLevel] = []
    var glyph: String?

    /// Product artwork to draw instead of the SF Symbol. With the noise-mode style the artwork stands in only
    /// while disconnected, so the active mode stays visible.
    func artworkGlyph(style: MenuBarIconStyle) -> String? {
        style == .noiseMode && !isDimmed ? nil : glyph
    }

    static func make(for snapshot: DeviceSnapshot, model: DeviceModel) -> MenuBarIcon {
        guard snapshot.status == .connected else {
            return MenuBarIcon(symbolName: defaultSymbol, isDimmed: true, batteryText: nil, glyph: model.glyph)
        }
        let battery = snapshot.state.battery
        let symbol = modeSymbol(in: snapshot.state, model: model) ?? defaultSymbol
        guard let battery, battery.hasComponents else {
            return MenuBarIcon(
                symbolName: symbol, isDimmed: false, batteryText: battery.map { "\($0.percent)%" }, glyph: model.glyph)
        }
        return MenuBarIcon(
            symbolName: symbol, isDimmed: false, batteryText: nil, budLevels: budLevels(of: battery), glyph: model.glyph
        )
    }

    private static func budLevels(of battery: Battery) -> [BudLevel] {
        [("L", battery.left), ("R", battery.right)].compactMap { side, level in
            level.map { BudLevel(side: side, percent: $0.percent) }
        }
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
