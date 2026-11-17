import AppKit
import SwiftUI

struct ConnectionFooter: View {
    let viewModel: HeadphoneViewModel

    var body: some View {
        HStack {
            if viewModel.snapshot.status == .disconnectedByUser {
                Button("Connect") { viewModel.connect() }
            } else {
                Button("Disconnect") { viewModel.disconnect() }
                    .help("Release the headphones so the phone app can connect")
            }
            Spacer()
            SettingsLink {
                Text("Settings…")
            }
            .simultaneousGesture(TapGesture().onEnded { NSApplication.shared.activate() })
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .buttonStyle(.borderless)
        .font(.callout)
        .padding(.top, 4)
    }
}
