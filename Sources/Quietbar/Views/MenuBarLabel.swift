import SwiftUI

struct MenuBarLabel: View {
    let icon: MenuBarIcon

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon.symbolName)
                .opacity(icon.isDimmed ? 0.45 : 1)
            if let battery = icon.batteryText {
                Text(battery)
            }
            ForEach(icon.budLevels, id: \.side) { bud in
                Text("\(Text(bud.side).foregroundStyle(.secondary)) \(bud.percent)")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Quietbar headphones \(accessibilityBattery)")
    }

    private var accessibilityBattery: String {
        if let text = icon.batteryText { return text }
        if icon.budLevels.isEmpty { return "disconnected" }
        return icon.budLevels.map { "\($0.side == "L" ? "left" : "right") \($0.percent) percent" }.joined(
            separator: ", ")
    }
}
