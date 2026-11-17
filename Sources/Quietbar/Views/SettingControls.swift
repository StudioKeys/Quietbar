import HeadphoneKit
import SwiftUI

struct SettingLabel: View {
    let descriptor: SettingDescriptor

    var body: some View {
        if let symbol = descriptor.symbol {
            Label(descriptor.title, systemImage: symbol)
        } else {
            Text(descriptor.title)
        }
    }
}

struct SettingSwitchRow: View {
    let descriptor: SettingDescriptor
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            SettingLabel(descriptor: descriptor)
            Spacer()
            Toggle(descriptor.title, isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
    }
}

struct ChoiceMenuRow: View {
    static let customTitle = "Custom"

    let descriptor: SettingDescriptor
    let options: [ChoiceOption]
    let selection: String?
    let onSelect: (String) -> Void

    var body: some View {
        HStack {
            SettingLabel(descriptor: descriptor)
            Spacer()
            Menu(title) {
                ForEach(options, id: \.id) { option in
                    Button(option.title) { onSelect(option.id) }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private var title: String {
        guard let selection else { return "–" }
        return options.first { $0.id == selection }?.title ?? Self.customTitle
    }
}

struct ModeButtons: View {
    let options: [ChoiceOption]
    let selection: String?
    let onSelect: (String) -> Void

    var body: some View {
        HStack(alignment: .top) {
            ForEach(options, id: \.id) { option in
                Button {
                    onSelect(option.id)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: option.symbol ?? "circle")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 46, height: 46)
                            .foregroundStyle(option.id == selection ? .white : .primary)
                            .background(
                                option.id == selection ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary),
                                in: .circle
                            )
                        Text(option.title)
                            .font(.caption2.weight(.medium))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(option.id == selection ? .isSelected : [])
            }
        }
    }
}
