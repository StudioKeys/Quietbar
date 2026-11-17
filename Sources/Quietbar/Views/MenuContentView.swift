import SwiftUI

struct MenuContentView: View {
    let viewModel: HeadphoneViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeaderView(viewModel: viewModel)
            if viewModel.isConnected {
                NoiseModeSection(viewModel: viewModel)
                EqSection(viewModel: viewModel)
                SpatialSection(viewModel: viewModel)
                BalanceSection(viewModel: viewModel)
                if let error = viewModel.snapshot.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            ConnectionFooter(viewModel: viewModel)
        }
        .padding(14)
        .frame(width: 300)
        .onAppear { viewModel.menuOpened() }
    }
}

private struct HeaderView: View {
    let viewModel: HeadphoneViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: viewModel.icon.symbolName)
                Text("Live 770NC").font(.headline)
                Spacer()
                if let battery = viewModel.state.battery {
                    Label("\(battery.percent)%", systemImage: battery.isCharging ? "battery.100.bolt" : "battery.75")
                        .labelStyle(.titleAndIcon)
                        .monospacedDigit()
                }
            }
            if !viewModel.isConnected {
                Text(viewModel.statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
