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
            ProductGlyph(glyph: viewModel.model.glyph, fallbackSymbol: "headphones")
                .frame(width: 40, height: 40)
                .background(.quaternary, in: .circle)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(viewModel.isConnected ? Color.green : Color.secondary.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                }
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
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 3) {
                if battery.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.green)
                }
                Text("\(battery.percent)%")
                    .font(.system(.callout, design: .monospaced, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(battery.percent <= 20 ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
            }
            SegmentedBatteryBar(percent: battery.percent, isCharging: battery.isCharging)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery \(battery.percent) percent\(battery.isCharging ? ", charging" : "")")
    }
}

struct DeviceTitle: View {
    let activeDevice: ActiveDevice

    var body: some View {
        if activeDevice.showsSwitcher {
            Menu {
                ForEach(activeDevice.switchableEntries) { entry in
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
