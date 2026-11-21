import AppKit
import HeadphoneKit
import SwiftUI

extension SettingDescriptor {
    var isDial: Bool {
        if case .level(_, style: .dial) = kind { return true }
        return false
    }
}

/// A frequency-response style equaliser: each band owns a full-height column, so a click or vertical drag
/// anywhere in it sets the gain, and scrolling over a column nudges it a decibel at a time. Built for
/// trackpads rather than precise knob grabbing.
struct EQCurve: View {
    let descriptors: [SettingDescriptor]
    let viewModel: HeadphoneViewModel

    @State private var live: [SettingID: CGFloat] = [:]
    @State private var committed: [SettingID: Int] = [:]
    @State private var dragging: SettingID?
    @State private var hovered: Int?
    @State private var scrollMonitor: Any?
    @State private var scrollAccumulator: CGFloat = 0
    @State private var pendingWrites: [SettingID: Task<Void, Never>] = [:]
    // Latest value per band that arrived while that band's previous write was still in flight.
    @State private var queued: [SettingID: Int] = [:]
    @Environment(\.colorScheme) private var colorScheme

    private static let graphHeight: CGFloat = 132
    private static let verticalInset: CGFloat = 14

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    columnHighlight(size: size)
                    Canvas { context, size in draw(in: &context, size: size) }
                    ForEach(Array(descriptors.enumerated()), id: \.element.id) { index, descriptor in
                        handle(descriptor, index: index, size: size)
                    }
                }
                .contentShape(.rect)
                .gesture(drag(size: size))
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let point): hovered = column(at: point.x, width: size.width)
                    case .ended:
                        hovered = nil
                        scrollAccumulator = 0
                    }
                }
            }
            .frame(height: Self.graphHeight)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Custom equaliser")

            HStack(spacing: 0) {
                ForEach(Array(descriptors.enumerated()), id: \.element.id) { index, descriptor in
                    VStack(spacing: 1) {
                        Text(descriptor.title.uppercased())
                            .font(.instrumentLabel)
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                        Text(HeadphoneViewModel.gainText(value(descriptor)))
                            .font(.system(.caption, design: .monospaced, weight: .medium))
                            .foregroundStyle(dragging == descriptor.id ? Color.accentColor : .primary)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                }
            }

            HStack {
                Text("Drag or scroll a band")
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
        .onChange(of: viewModel.snapshot.state) { _, _ in settleCommitted() }
        .onChange(of: viewModel.pending) { _, _ in
            sendQueued()
            settleCommitted()
        }
        .onAppear(perform: installScrollMonitor)
        .onDisappear(perform: removeScrollMonitor)
    }

    // MARK: Drawing

    private func columnHighlight(size: CGSize) -> some View {
        let width = size.width / CGFloat(max(descriptors.count, 1))
        let active = dragging.flatMap { id in descriptors.firstIndex { $0.id == id } } ?? hovered
        return RoundedRectangle(cornerRadius: 10)
            .fill(Color.primary.opacity(active == nil ? 0 : 0.06))
            .frame(width: width - 6, height: size.height)
            .position(x: width * (CGFloat(active ?? 0) + 0.5), y: size.height / 2)
            .animation(.easeOut(duration: 0.15), value: active)
            .allowsHitTesting(false)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let primary = Color.primary
        let zeroY = y(forFraction: 0.5, height: size.height)
        for fraction in [0.0, 0.5, 1.0] {
            let lineY = y(forFraction: fraction, height: size.height)
            var line = Path()
            line.move(to: CGPoint(x: 0, y: lineY))
            line.addLine(to: CGPoint(x: size.width, y: lineY))
            context.stroke(
                line, with: .color(primary.opacity(fraction == 0.5 ? 0.25 : 0.10)),
                style: StrokeStyle(lineWidth: 1, dash: fraction == 0.5 ? [] : [2, 4]))
        }

        let points = curvePoints(size: size)
        let curve = Self.smoothPath(through: points)
        var area = curve
        area.addLine(to: CGPoint(x: size.width, y: zeroY))
        area.addLine(to: CGPoint(x: 0, y: zeroY))
        area.closeSubpath()
        context.fill(area, with: .color(primary.opacity(0.10)))
        context.stroke(curve, with: .color(primary.opacity(0.85)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private func handle(_ descriptor: SettingDescriptor, index: Int, size: CGSize) -> some View {
        let current = value(descriptor)
        let isActive = dragging == descriptor.id
        return Circle()
            .fill(colorScheme == .dark ? Color.white : Color.black)
            .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 0.5))
            .frame(width: isActive ? 18 : 14, height: isActive ? 18 : 14)
            .position(
                x: columnCenter(index, width: size.width), y: y(forFraction: fraction(descriptor), height: size.height)
            )
            // The Canvas curve redraws without interpolation, so the handle must move in lockstep with it.
            .animation(nil, value: fraction(descriptor))
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

    // MARK: Interaction

    private func drag(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                let id = dragging ?? column(at: gesture.startLocation.x, width: size.width).map { descriptors[$0].id }
                guard let id, let descriptor = descriptors.first(where: { $0.id == id }) else { return }
                if dragging == nil { dragging = id }
                let next = fraction(forY: gesture.location.y, height: size.height)
                if level(for: next, descriptor) != value(descriptor) {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
                live[id] = next
            }
            .onEnded { _ in
                guard let id = dragging, let descriptor = descriptors.first(where: { $0.id == id }),
                    let continuous = live[id]
                else {
                    dragging = nil
                    return
                }
                dragging = nil
                live[id] = nil
                commit(descriptor, level(for: continuous, descriptor))
            }
    }

    private func installScrollMonitor() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard let index = hovered, dragging == nil, isEditable else { return event }
            handleScroll(event, descriptor: descriptors[index])
            return nil
        }
    }

    private func removeScrollMonitor() {
        if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
        scrollMonitor = nil
        for task in pendingWrites.values { task.cancel() }
        pendingWrites = [:]
        queued = [:]
    }

    private func handleScroll(_ event: NSEvent, descriptor: SettingDescriptor) {
        // Momentum after the fingers lift would overshoot; only direct movement adjusts the band.
        guard event.momentumPhase.isEmpty else { return }
        // Physical "up" (fingers or wheel) raises the gain regardless of the natural-scrolling setting.
        let delta = event.scrollingDeltaY * (event.isDirectionInvertedFromDevice ? -1 : 1)
        scrollAccumulator += event.hasPreciseScrollingDeltas ? delta : delta.sign == .minus ? -12 : 12
        let steps = Int(scrollAccumulator / 12)
        guard steps != 0 else { return }
        scrollAccumulator -= CGFloat(steps) * 12

        let range = levelRange(descriptor)
        let next = min(max(value(descriptor) + steps, range.lowerBound), range.upperBound)
        guard next != value(descriptor) else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        committed[descriptor.id] = next

        // Coalesce a burst of scroll steps into a single write once the gesture settles.
        pendingWrites[descriptor.id]?.cancel()
        pendingWrites[descriptor.id] = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            pendingWrites[descriptor.id] = nil
            commit(descriptor, next)
        }
    }

    private func commit(_ descriptor: SettingDescriptor, _ level: Int) {
        committed[descriptor.id] = level
        // The view model ignores a change while the same setting is pending, so hold it until that write finishes.
        if viewModel.pending.contains(descriptor.id) {
            queued[descriptor.id] = level
        } else {
            viewModel.set(descriptor.id, .level(level))
        }
    }

    private func sendQueued() {
        for (id, level) in queued where !viewModel.pending.contains(id) {
            queued[id] = nil
            viewModel.set(id, .level(level))
        }
    }

    // Show the device's value again only once nothing for that band is still on its way.
    private func settleCommitted() {
        for id in committed.keys
        where dragging != id && pendingWrites[id] == nil && queued[id] == nil && !viewModel.pending.contains(id) {
            committed[id] = nil
        }
    }

    // MARK: Geometry

    private func column(at x: CGFloat, width: CGFloat) -> Int? {
        guard !descriptors.isEmpty, width > 0 else { return nil }
        return min(max(Int(x / (width / CGFloat(descriptors.count))), 0), descriptors.count - 1)
    }

    private func columnCenter(_ index: Int, width: CGFloat) -> CGFloat {
        width / CGFloat(descriptors.count) * (CGFloat(index) + 0.5)
    }

    private func y(forFraction fraction: CGFloat, height: CGFloat) -> CGFloat {
        let usable = height - Self.verticalInset * 2
        return Self.verticalInset + usable * (1 - fraction)
    }

    private func fraction(forY y: CGFloat, height: CGFloat) -> CGFloat {
        let usable = height - Self.verticalInset * 2
        return min(max(1 - (y - Self.verticalInset) / usable, 0), 1)
    }

    // Flat shelves beyond Bass and Treble make the line read as a frequency response.
    private func curvePoints(size: CGSize) -> [CGPoint] {
        let points = descriptors.indices.map { index in
            CGPoint(
                x: columnCenter(index, width: size.width),
                y: y(forFraction: fraction(descriptors[index]), height: size.height))
        }
        guard let first = points.first, let last = points.last else { return [] }
        return [CGPoint(x: 0, y: first.y)] + points + [CGPoint(x: size.width, y: last.y)]
    }

    static func smoothPath(through points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        path.move(to: points[0])
        for index in 0..<(points.count - 1) {
            let p0 = points[max(index - 1, 0)]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = points[min(index + 2, points.count - 1)]
            path.addCurve(
                to: p2,
                control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
                control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6))
        }
        return path
    }

    // MARK: Values

    private func fraction(_ descriptor: SettingDescriptor) -> CGFloat {
        if let continuous = live[descriptor.id] { return continuous }
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
        if let continuous = live[descriptor.id] { return level(for: continuous, descriptor) }
        if let pending = committed[descriptor.id] { return pending }
        if case .level(let level) = viewModel.value(for: descriptor.id) { return level }
        return 0
    }

    private var isEditable: Bool {
        viewModel.canEdit && descriptors.allSatisfy { viewModel.value(for: $0.id) != nil }
    }
}
