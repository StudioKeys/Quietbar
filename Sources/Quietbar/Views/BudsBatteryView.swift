import HeadphoneKit
import SwiftUI

struct BudsBatteryView: View {
    let battery: Battery

    var body: some View {
        HStack(alignment: .top) {
            ring("Left", symbol: "earbud.left", level: battery.left)
            ring("Right", symbol: "earbud.right", level: battery.right)
            ring("Case", symbol: "earbuds.case.fill", level: battery.caseLevel)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 16))
    }

    @ViewBuilder
    private func ring(_ title: String, symbol: String, level: BatteryLevel?) -> some View {
        if let level {
            BatteryRing(title: title, symbol: symbol, level: level)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct BatteryRing: View {
    static let diameter: CGFloat = 56
    static let lineWidth: CGFloat = 4

    let title: String
    let symbol: String
    let level: BatteryLevel

    private var style: BatteryRingStyle { .style(for: level) }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: Self.lineWidth)
                Circle()
                    .trim(from: 0, to: CGFloat(level.percent) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                if style == .charging {
                    chargingBadge
                }
            }
            .frame(width: Self.diameter, height: Self.diameter)
            Text("\(level.percent)%")
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(style == .low ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(level.percent) percent\(level.isCharging ? ", charging" : "")")
    }

    private var color: Color {
        switch style {
        case .normal: .primary
        case .low: .red
        case .charging: .green
        }
    }

    private var chargingBadge: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.green)
            .padding(3)
            .background(.background, in: .circle)
            .offset(y: -Self.diameter / 2)
    }
}
