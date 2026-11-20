import HeadphoneKit
import SwiftUI

extension Color {
    static let quietbarAccent = Color(red: 0xD7 / 255, green: 0x19 / 255, blue: 0x21 / 255)
}

extension Font {
    static let instrumentLabel = Font.system(.caption2, design: .monospaced, weight: .medium)
}

struct TwoColumnGrid<Item, Cell: View>: View {
    let items: [Item]
    var spacing: CGFloat = 8
    var columns = 2
    @ViewBuilder let cell: (Item) -> Cell

    var body: some View {
        Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
            ForEach(Array(stride(from: 0, to: items.count, by: columns)), id: \.self) { start in
                GridRow {
                    ForEach(start..<(start + columns), id: \.self) { index in
                        if index < items.count {
                            cell(items[index])
                        } else {
                            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                        }
                    }
                }
            }
        }
    }
}

struct SelectedFill {
    let colorScheme: ColorScheme

    var background: Color { colorScheme == .dark ? .white : .black }
    var foreground: Color { colorScheme == .dark ? .black : .white }
}

struct LevelBars: View {
    let options: [ChoiceOption]
    let selection: String?
    let onSelect: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.id) { option in
                let isSelected = option.id == selection
                Button {
                    onSelect(option.id)
                } label: {
                    VStack(spacing: 6) {
                        Capsule()
                            .fill(
                                isSelected
                                    ? AnyShapeStyle(SelectedFill(colorScheme: colorScheme).background)
                                    : AnyShapeStyle(.quaternary)
                            )
                            .frame(height: 5)
                        Text(option.title)
                            .font(.caption)
                            .foregroundStyle(isSelected ? .primary : .secondary)
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

struct PresetPills: View {
    let options: [ChoiceOption]
    let selection: String?
    let onSelect: (String) -> Void

    var body: some View {
        TwoColumnGrid(items: options, spacing: 6, columns: 3) { option in
            let isSelected = option.id == selection
            Button {
                onSelect(option.id)
            } label: {
                VStack(spacing: 3) {
                    if let symbol = option.symbol {
                        Image(systemName: symbol).font(.system(size: 12, weight: .medium))
                    }
                    Text(option.title.uppercased())
                        .font(.instrumentLabel)
                        .tracking(0.4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .background(
                    isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary),
                    in: .rect(cornerRadius: 12)
                )
                .contentShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
        .animation(.easeOut(duration: 0.16), value: selection)
    }
}

struct ToggleTile: View {
    let descriptor: SettingDescriptor
    let viewModel: HeadphoneViewModel
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: descriptor.symbol ?? "circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(descriptor.title)
            Spacer()
            Toggle(descriptor.title, isOn: binding)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
        .padding(.vertical, 2)
        .disabled(
            !viewModel.canEdit || viewModel.pending.contains(descriptor.id)
                || viewModel.value(for: descriptor.id) == nil
        )
        .help(helpText)
    }

    private var helpText: String {
        if descriptor.appliesWithReconnect { return "Headphones reconnect briefly to apply." }
        return descriptor.title
    }

    private var binding: Binding<Bool> {
        Binding(get: { viewModel.isOn(descriptor.id) }, set: { viewModel.set(descriptor.id, .bool($0)) })
    }
}

struct ToggleTileGrid: View {
    let descriptors: [SettingDescriptor]
    let viewModel: HeadphoneViewModel

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(descriptors.enumerated()), id: \.element.id) { index, descriptor in
                if index > 0 { Divider() }
                ToggleTile(descriptor: descriptor, viewModel: viewModel)
            }
        }
    }
}

struct SegmentedBatteryBar: View {
    let percent: Int
    let isCharging: Bool
    var segments = 10

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { index in
                Capsule()
                    .fill(fill(for: index))
                    .frame(width: 5, height: 9)
            }
        }
        .accessibilityHidden(true)
    }

    private func fill(for index: Int) -> AnyShapeStyle {
        let lit = Int((Double(percent) / 100 * Double(segments)).rounded(.up))
        guard index < lit else { return AnyShapeStyle(.quaternary) }
        if isCharging { return AnyShapeStyle(.green) }
        return percent <= 20 ? AnyShapeStyle(Color.quietbarAccent) : AnyShapeStyle(.primary)
    }
}
