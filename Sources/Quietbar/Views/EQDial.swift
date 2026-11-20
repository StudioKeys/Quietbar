import AppKit
import HeadphoneKit
import SwiftUI

extension SettingDescriptor {
    var isDial: Bool {
        if case .level(_, style: .dial) = kind { return true }
        return false
    }
}

/// A radial three-band equaliser. Each band is a lobe on its own spoke; the lobes fuse into one fluid body.
struct EQDial: View {
    let descriptors: [SettingDescriptor]
    let viewModel: HeadphoneViewModel

    @State private var dragFraction: [SettingID: CGFloat] = [:]
    @State private var committed: [SettingID: Int] = [:]
    @State private var dragging: SettingID?
    @Environment(\.colorScheme) private var colorScheme

    static let size: CGFloat = 214
    static let innerRadius: CGFloat = 14
    static let outerRadius: CGFloat = 62
    // Mid points up, Bass lower-left and Treble lower-right.
    static let angles: [Double] = [150, 270, 30]

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(Color.primary.opacity(0.07))
                MetaballBlob(fractions: animatedFractions, isDark: colorScheme == .dark)
                    .animation(dragging == nil ? .spring(duration: 0.4, bounce: 0.3) : nil, value: animatedFractions)
                Canvas { context, size in drawSpokes(in: &context, size: size) }
                ForEach(Array(descriptors.enumerated()), id: \.element.id) { index, descriptor in
                    knob(descriptor, index: index)
                    rimLabel(descriptor, index: index)
                }
            }
            .frame(width: Self.size, height: Self.size)
            .contentShape(.circle)
            .gesture(drag)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Custom equaliser")

            HStack {
                Text("Drag a lobe outward to boost it")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    for descriptor in descriptors where value(descriptor) != 0 {
                        commit(descriptor, 0)
                    }
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise").font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(descriptors.allSatisfy { value($0) == 0 })
                .help("Set every band to 0 dB")
            }
        }
        .disabled(!isEditable)
        .opacity(isEditable ? 1 : 0.5)
        .onChange(of: viewModel.snapshot.state) { _, _ in
            if dragging == nil { committed = [:] }
        }
    }

    // MARK: Drawing

    private var animatedFractions: EQFractions {
        EQFractions(descriptors.map { fraction($0) })
    }

    private func drawSpokes(in context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        for index in descriptors.indices {
            for step in stride(from: 0.0, through: 1.0, by: 1.0 / 3.0) {
                let point = Self.point(index: index, fraction: step, center: center)
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - 2.5, y: point.y - 2.5, width: 5, height: 5)),
                    with: .color(.primary.opacity(0.28)))
            }
        }
        let tip = Self.point(index: 1, fraction: 1.25, center: center)
        context.fill(
            Path(ellipseIn: CGRect(x: tip.x - 2.5, y: tip.y - 2.5, width: 5, height: 5)),
            with: .color(.primary.opacity(0.28)))
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - 8, y: center.y - 8, width: 16, height: 16)),
            with: .color(colorScheme == .dark ? .black : .white))
    }

    private func knob(_ descriptor: SettingDescriptor, index: Int) -> some View {
        let center = CGPoint(x: Self.size / 2, y: Self.size / 2)
        let current = value(descriptor)
        let isActive = dragging == descriptor.id
        return Circle()
            .fill(colorScheme == .dark ? Color.white : Color.black)
            .frame(width: isActive ? 16 : 12, height: isActive ? 16 : 12)
            .position(Self.point(index: index, fraction: fraction(descriptor), center: center))
            .animation(dragging == nil ? .spring(duration: 0.4, bounce: 0.3) : nil, value: fraction(descriptor))
            .animation(.easeOut(duration: 0.12), value: isActive)
            .accessibilityElement()
            .accessibilityLabel(descriptor.title)
            .accessibilityValue(HeadphoneViewModel.gainText(current))
            .accessibilityAdjustableAction { direction in
                let range = levelRange(descriptor)
                let next = direction == .increment ? current + 1 : current - 1
                commit(descriptor, min(max(next, range.lowerBound), range.upperBound))
            }
    }

    private func rimLabel(_ descriptor: SettingDescriptor, index: Int) -> some View {
        let center = CGPoint(x: Self.size / 2, y: Self.size / 2)
        let angle = Self.angles[index]
        let position = Self.point(atDegrees: angle, radius: Self.size / 2 - 14, center: center)
        let gain = value(descriptor)
        return HStack(spacing: 4) {
            Text(descriptor.title)
                .foregroundStyle(.secondary)
            Text(gain > 0 ? "+\(gain)" : "\(gain)")
                .foregroundStyle(dragging == descriptor.id ? Color.quietbarAccent : .primary)
                .monospacedDigit()
        }
        .font(.system(.caption, design: .monospaced))
        .tracking(0.6)
        .fixedSize()
        .rotationEffect(.degrees(angle == 270 ? 0 : angle - 90))
        .position(position)
        .accessibilityHidden(true)
    }

    // MARK: Interaction

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                let center = CGPoint(x: Self.size / 2, y: Self.size / 2)
                let id = dragging ?? nearestBand(to: gesture.startLocation, center: center)
                guard let id, let index = descriptors.firstIndex(where: { $0.id == id }) else { return }
                if dragging == nil { dragging = id }
                let continuous = Self.fraction(along: index, at: gesture.location, center: center)
                let before = level(for: dragFraction[id] ?? fraction(descriptors[index]), descriptors[index])
                dragFraction[id] = continuous
                if level(for: continuous, descriptors[index]) != before {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
            }
            .onEnded { _ in
                guard let id = dragging, let descriptor = descriptors.first(where: { $0.id == id }),
                    let continuous = dragFraction[id]
                else {
                    dragging = nil
                    return
                }
                dragging = nil
                dragFraction[id] = nil
                commit(descriptor, level(for: continuous, descriptor))
            }
    }

    private func commit(_ descriptor: SettingDescriptor, _ level: Int) {
        committed[descriptor.id] = level
        viewModel.set(descriptor.id, .level(level))
    }

    private func nearestBand(to point: CGPoint, center: CGPoint) -> SettingID? {
        let angle = atan2(point.y - center.y, point.x - center.x) * 180 / .pi
        let index = Self.angles.indices.min { lhs, rhs in
            Self.angularDistance(Self.angles[lhs], angle) < Self.angularDistance(Self.angles[rhs], angle)
        }
        return index.flatMap { $0 < descriptors.count ? descriptors[$0].id : nil }
    }

    // MARK: Values

    private func fraction(_ descriptor: SettingDescriptor) -> CGFloat {
        if let live = dragFraction[descriptor.id] { return live }
        let range = levelRange(descriptor)
        return CGFloat(value(descriptor) - range.lowerBound) / CGFloat(range.upperBound - range.lowerBound)
    }

    private func level(for fraction: CGFloat, _ descriptor: SettingDescriptor) -> Int {
        let range = levelRange(descriptor)
        let raw = Double(range.lowerBound) + Double(fraction) * Double(range.upperBound - range.lowerBound)
        return min(max(Int(raw.rounded()), range.lowerBound), range.upperBound)
    }

    private func levelRange(_ descriptor: SettingDescriptor) -> ClosedRange<Int> {
        if case .level(let range, _) = descriptor.kind { return range }
        return 0...0
    }

    private func value(_ descriptor: SettingDescriptor) -> Int {
        if let live = dragFraction[descriptor.id] { return level(for: live, descriptor) }
        if let pending = committed[descriptor.id] { return pending }
        if case .level(let level) = viewModel.value(for: descriptor.id) { return level }
        return 0
    }

    private var isEditable: Bool {
        viewModel.canEdit && descriptors.allSatisfy { viewModel.value(for: $0.id) != nil }
    }

    // MARK: Geometry

    static func point(index: Int, fraction: CGFloat, center: CGPoint) -> CGPoint {
        point(atDegrees: angles[index], radius: innerRadius + (outerRadius - innerRadius) * fraction, center: center)
    }

    static func point(atDegrees degrees: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(x: center.x + cos(radians) * radius, y: center.y + sin(radians) * radius)
    }

    static func fraction(along index: Int, at point: CGPoint, center: CGPoint) -> CGFloat {
        let radians = angles[index] * .pi / 180
        let projected = (point.x - center.x) * cos(radians) + (point.y - center.y) * sin(radians)
        return min(max((projected - innerRadius) / (outerRadius - innerRadius), 0), 1)
    }

    static func angularDistance(_ a: Double, _ b: Double) -> Double {
        let delta = abs((a - b).truncatingRemainder(dividingBy: 360))
        return min(delta, 360 - delta)
    }
}

struct EQFractions: Equatable, VectorArithmetic {
    var values: [CGFloat]

    init(_ values: [CGFloat]) { self.values = values }

    static var zero: EQFractions { EQFractions([0, 0, 0]) }

    static func + (lhs: EQFractions, rhs: EQFractions) -> EQFractions {
        EQFractions(zip(lhs.padded, rhs.padded).map(+))
    }

    static func - (lhs: EQFractions, rhs: EQFractions) -> EQFractions {
        EQFractions(zip(lhs.padded, rhs.padded).map(-))
    }

    mutating func scale(by rhs: Double) {
        values = padded.map { $0 * CGFloat(rhs) }
    }

    var magnitudeSquared: Double {
        padded.reduce(0) { $0 + Double($1 * $1) }
    }

    private var padded: [CGFloat] {
        values + Array(repeating: 0, count: max(0, 3 - values.count))
    }
}

/// Metaball rendering: blurred circles are alpha-thresholded so overlapping lobes melt into one shape.
struct MetaballBlob: View, Animatable {
    var fractions: EQFractions
    let isDark: Bool

    nonisolated var animatableData: EQFractions {
        get { fractions }
        set { fractions = newValue }
    }

    private static let lobeRadius: CGFloat = 30
    private static let bodyRadius: CGFloat = 46
    private static let neckWidth: CGFloat = 52

    var body: some View {
        let rim = isDark ? Color(white: 0.40) : Color(white: 0.62)
        let fill = isDark ? Color(white: 0.27) : Color(white: 0.80)
        ZStack {
            Canvas { context, size in
                context.addFilter(.alphaThreshold(min: 0.5, color: rim))
                context.addFilter(.blur(radius: 11))
                context.drawLayer { layer in drawCircles(in: &layer, size: size, inset: 0) }
            }
            Canvas { context, size in
                context.addFilter(.blur(radius: 2.5))
                context.drawLayer { inner in
                    inner.addFilter(.alphaThreshold(min: 0.5, color: fill))
                    inner.addFilter(.blur(radius: 11))
                    inner.drawLayer { layer in drawCircles(in: &layer, size: size, inset: 2.5) }
                }
            }
        }
        .frame(width: EQDial.size, height: EQDial.size)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawCircles(in context: inout GraphicsContext, size: CGSize, inset: CGFloat) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        func disc(_ point: CGPoint, _ radius: CGFloat) {
            let r = radius - inset
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
                with: .color(.white))
        }
        disc(center, Self.bodyRadius)
        for (index, fraction) in fractions.values.prefix(3).enumerated() {
            let lobe = EQDial.point(index: index, fraction: fraction, center: center)
            // A neck from the body keeps every lobe part of one continuous shape at any distance.
            var neck = Path()
            neck.move(to: center)
            neck.addLine(to: lobe)
            context.stroke(
                neck, with: .color(.white), style: StrokeStyle(lineWidth: Self.neckWidth - inset * 2, lineCap: .round))
            disc(lobe, Self.lobeRadius)
        }
    }
}
