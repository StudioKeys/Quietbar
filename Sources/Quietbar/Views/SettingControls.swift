import HeadphoneKit
import SwiftUI

struct SettingLabel: View {
    let descriptor: SettingDescriptor

    var body: some View {
        if let symbol = descriptor.symbol {
            Label(descriptor.title, systemImage: symbol)
                .symbolRenderingMode(.monochrome)
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let selected = SelectedFill(colorScheme: colorScheme)
        HStack(alignment: .top) {
            ForEach(options, id: \.id) { option in
                let isSelected = option.id == selection
                Button {
                    onSelect(option.id)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: option.symbol ?? "circle")
                            .font(.system(size: 18, weight: .regular))
                            .frame(width: 48, height: 48)
                            .foregroundStyle(isSelected ? AnyShapeStyle(selected.foreground) : AnyShapeStyle(.primary))
                            .background(
                                isSelected ? AnyShapeStyle(selected.background) : AnyShapeStyle(.quaternary),
                                in: .circle
                            )
                        Text(option.title)
                            .font(.caption)
                            .foregroundStyle(isSelected ? .primary : .secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .animation(.easeOut(duration: 0.16), value: selection)
    }
}
