import HeadphoneKit
import SwiftUI

struct LevelRow: View {
    let descriptor: SettingDescriptor
    let range: ClosedRange<Int>
    let style: LevelStyle
    let value: Int?
    let onCommit: (Int) -> Void
    @State private var draft = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                SettingLabel(descriptor: descriptor)
                Spacer()
                Text(badge)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: .capsule)
            }
            HStack(spacing: 8) {
                if style == .balance { Text("L").font(.caption.weight(.semibold)) }
                Slider(value: $draft, in: Double(range.lowerBound)...Double(range.upperBound), step: 1) { isEditing in
                    if !isEditing { onCommit(Int(draft)) }
                }
                .accessibilityLabel(descriptor.title)
                .accessibilityValue(badge)
                if style == .balance { Text("R").font(.caption.weight(.semibold)) }
            }
        }
        .onChange(of: value, initial: true) { _, newValue in
            if let newValue { draft = Double(newValue) }
        }
    }

    private var badge: String {
        switch style {
        case .balance: HeadphoneViewModel.balanceText(Int(draft))
        case .dial: HeadphoneViewModel.gainText(Int(draft))
        case .slider: "\(Int(draft))"
        }
    }
}
