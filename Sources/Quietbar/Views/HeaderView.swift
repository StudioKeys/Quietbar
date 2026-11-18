import HeadphoneKit
import SwiftUI

struct HeaderView: View {
    let activeDevice: ActiveDevice

    private var viewModel: HeadphoneViewModel { activeDevice.viewModel }

    var body: some View {
        VStack(spacing: 12) {
            deviceRow
            if let battery = viewModel.battery, battery.hasComponents {
                BudsBatteryView(battery: battery)
            }
        }
    }

    private var deviceRow: some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.icon.symbolName)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 34, height: 34)
                .background(.quaternary, in: .circle)
            VStack(alignment: .leading, spacing: 1) {
                DeviceTitle(activeDevice: activeDevice)
                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let battery = viewModel.battery, !battery.hasComponents {
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

struct DeviceTitle: View {
    let activeDevice: ActiveDevice

    var body: some View {
        if activeDevice.showsSwitcher {
            Menu {
                ForEach(activeDevice.entries) { entry in
                    Button {
                        Task { await activeDevice.select(entry.id) }
                    } label: {
                        if entry.id == activeDevice.selected.id {
                            Label(activeDevice.displayName(for: entry), systemImage: "checkmark")
                        } else {
                            Text(activeDevice.displayName(for: entry))
                        }
                        Text(entry.name)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(activeDevice.viewModel.deviceName).font(.headline)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .fixedSize()
            .help("Choose headphones")
        } else {
            Text(activeDevice.viewModel.deviceName).font(.headline)
        }
    }
}
