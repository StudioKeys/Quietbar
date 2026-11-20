import HeadphoneKit
import SwiftUI

struct GlassSegmentedControl: View {
    let options: [ChoiceOption]
    let selection: String?
    let onSelect: (String) -> Void
    @AppStorage(GlassPreference.key) private var isGlassEnabled = true
    @State private var dragLocation: CGFloat?

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width / CGFloat(max(options.count, 1))
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                thumb
                    .frame(width: width - 4, height: proxy.size.height - 4)
                    .offset(x: thumbOffset(segmentWidth: width) + 2)
                    .animation(.easeOut(duration: 0.16), value: selectedIndex)
                    .animation(.linear(duration: 0.08), value: dragLocation)
                HStack(spacing: 0) {
                    ForEach(options, id: \.id) { option in
                        Text(option.title)
                            .font(.caption.weight(option.id == selection ? .semibold : .regular))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(.rect)
                            .onTapGesture { onSelect(option.id) }
                            .accessibilityAddTraits(option.id == selection ? [.isButton, .isSelected] : .isButton)
                    }
                }
            }
            .gesture(drag(segmentWidth: width))
        }
        .frame(height: 28)
    }

    @ViewBuilder
    private var thumb: some View {
        if isGlassEnabled {
            Capsule().fill(.clear).glassEffect(.regular.interactive(), in: .capsule)
        } else {
            Capsule()
                .fill(.background)
                .overlay(Capsule().stroke(.quaternary))
        }
    }

    private var selectedIndex: Int? {
        options.firstIndex { $0.id == selection }
    }

    private func thumbOffset(segmentWidth: CGFloat) -> CGFloat {
        if let dragLocation {
            let maxOffset = segmentWidth * CGFloat(options.count - 1)
            return min(max(dragLocation - segmentWidth / 2, 0), maxOffset)
        }
        return segmentWidth * CGFloat(selectedIndex ?? 0)
    }

    private func drag(segmentWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { dragLocation = $0.location.x }
            .onEnded { gesture in
                dragLocation = nil
                let index = Int((gesture.location.x / segmentWidth).rounded(.down))
                let clamped = min(max(index, 0), options.count - 1)
                onSelect(options[clamped].id)
            }
    }
}
