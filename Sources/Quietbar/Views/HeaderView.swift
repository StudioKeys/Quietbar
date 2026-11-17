import HeadphoneKit
import SwiftUI

struct HeaderView: View {
    let viewModel: HeadphoneViewModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.icon.symbolName)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 34, height: 34)
                .background(.quaternary, in: .circle)
            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.deviceName).font(.headline)
                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let battery = viewModel.battery {
                BatteryLabel(battery: battery)
            }
        }
    }
}

private struct BatteryLabel: View {
    let battery: Battery

    var body: some View {
        HStack(spacing: 4) {
            Text("\(battery.percent)%")
                .font(.callout.weight(.semibold))
                .monospacedDigit()
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(battery.percent <= 20 ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Battery \(battery.percent) percent\(battery.isCharging ? ", charging" : "")")
    }

    private var symbol: String {
        if battery.isCharging { return "battery.100percent.bolt" }
        switch battery.percent {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}
