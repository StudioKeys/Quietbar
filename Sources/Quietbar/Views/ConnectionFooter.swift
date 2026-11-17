import AppKit
import SwiftUI

struct ConnectionFooter: View {
    let viewModel: HeadphoneViewModel
    @AppStorage(GlassPreference.key) private var isGlassEnabled = true

    var body: some View {
        HStack(spacing: 8) {
            connectionButton
            Spacer()
            SettingsLink {
                Image(systemName: "gearshape")
                    .frame(width: 18, height: 18)
            }
            .buttonBorderShape(.circle)
            .simultaneousGesture(TapGesture().onEnded { NSApplication.shared.activate() })
            .help("Settings")
            .accessibilityLabel("Settings")
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
        if viewModel.snapshot.status == .disconnectedByUser {
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
