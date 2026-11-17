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
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Quietbar headphones \(icon.batteryText ?? "disconnected")")
    }
}
