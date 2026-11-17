import HeadphoneKit
import SwiftUI

struct SettingRow: View {
    let descriptor: SettingDescriptor
    let viewModel: HeadphoneViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            content
            if descriptor.appliesWithReconnect, case .toggle = descriptor.kind {
                Text("Headphones reconnect briefly to apply.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(viewModel.pending.contains(descriptor.id) || viewModel.value(for: descriptor.id) == nil)
    }

    @ViewBuilder
    private var content: some View {
        switch descriptor.kind {
        case .toggle:
            SettingSwitchRow(descriptor: descriptor, isOn: binding(bool: descriptor.id))
        case .choice(let options, style: .modeButtons):
            ModeButtons(options: options, selection: selectedChoice) { viewModel.set(descriptor.id, .choice($0)) }
        case .choice(let options, style: .menu):
            ChoiceMenuRow(descriptor: descriptor, options: options, selection: selectedChoice) {
                viewModel.set(descriptor.id, .choice($0))
            }
        case .choice(let options, style: .segmented):
            GlassSegmentedControl(options: options, selection: selectedChoice) {
                viewModel.set(descriptor.id, .choice($0))
            }
            .accessibilityLabel(descriptor.title)
        case .level(let range, let style):
            LevelRow(descriptor: descriptor, range: range, style: style, value: selectedLevel) {
                viewModel.set(descriptor.id, .level($0))
            }
        }
    }

    private var selectedChoice: String? {
        guard case .choice(let id) = viewModel.value(for: descriptor.id) else { return nil }
        return id
    }

    private var selectedLevel: Int? {
        guard case .level(let level) = viewModel.value(for: descriptor.id) else { return nil }
        return level
    }

    private func binding(bool id: SettingID) -> Binding<Bool> {
        Binding(
            get: { viewModel.isOn(id) },
            set: { viewModel.set(id, .bool($0)) }
        )
    }
}
