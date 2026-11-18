import AppKit
import SwiftUI

struct ConnectionFooter: View {
    let viewModel: HeadphoneViewModel
    @Binding var isShowingSettings: Bool
    @AppStorage(GlassPreference.key) private var isGlassEnabled = true

    var body: some View {
        HStack(spacing: 8) {
            connectionButton
            Spacer()
            Button {
                isShowingSettings.toggle()
            } label: {
                Image(systemName: isShowingSettings ? "gearshape.fill" : "gearshape")
                    .frame(width: 18, height: 18)
            }
            .buttonBorderShape(.circle)
            .help("Settings")
            .accessibilityLabel(isShowingSettings ? "Close settings" : "Settings")
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .frame(width: 18, height: 18)
            }
            .buttonBorderShape(.circle)
            .keyboardShortcut("q")
            .help("Quit Quietbar")
            .accessibilityLabel("Quit Quietbar")
        }
        .footerButtonStyle(isGlass: isGlassEnabled)
        .controlSize(.regular)
        .padding(.top, 2)
    }

    @ViewBuilder
    private var connectionButton: some View {
        if viewModel.showsConnectButton {
            Button {
                viewModel.connect()
            } label: {
                Label("Connect", systemImage: "link")
            }
            .buttonBorderShape(.capsule)
        } else {
            Button {
                viewModel.disconnect()
            } label: {
                Label("Disconnect", systemImage: "personalhotspot.slash")
            }
            .buttonBorderShape(.capsule)
            .help("Release the headphones so the phone app can connect")
        }
    }
}

extension View {
    @ViewBuilder
    fileprivate func footerButtonStyle(isGlass: Bool) -> some View {
        if isGlass {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }
}
