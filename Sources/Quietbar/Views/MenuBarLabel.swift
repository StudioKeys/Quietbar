import SwiftUI

struct MenuBarLabel: View {
    let icon: MenuBarIcon
    @AppStorage(MenuBarIconStyle.key) private var style = MenuBarIconStyle.product

    var body: some View {
        HStack(spacing: 3) {
            Group {
                if let artwork = ProductGlyph.menuBarImage(for: icon.artworkGlyph(style: style)) {
                    Image(nsImage: artwork)
                } else {
                    Image(systemName: icon.symbolName)
                }
            }
            .opacity(icon.isDimmed ? 0.45 : 1)
            if let battery = icon.batteryText {
                Text(battery)
            }
            if !icon.budLevels.isEmpty {
                budsText
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Quietbar headphones \(accessibilityBattery)")
    }

    private var budsText: Text {
        icon.budLevels.enumerated().reduce(Text(verbatim: "")) { text, entry in
            let gap = entry.offset == 0 ? "" : " "
            return Text("\(text)\(gap)\(Text(entry.element.side).foregroundStyle(.secondary)) \(entry.element.percent)")
        }
    }

    private var accessibilityBattery: String {
        if let text = icon.batteryText { return text }
        if icon.budLevels.isEmpty { return "disconnected" }
        return icon.budLevels.map { "\($0.side == "L" ? "left" : "right") \($0.percent) percent" }.joined(
            separator: ", ")
    }
}
