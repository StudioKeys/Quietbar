import AppKit
import SwiftUI

struct ConnectionFooter: View {
    let viewModel: HeadphoneViewModel

    var body: some View {
        HStack {
            if viewModel.snapshot.status == .disconnectedByUser {
                Button("Connect") { viewModel.connect() }
            } else {
                Button("Disconnect (let phone in)") { viewModel.disconnect() }
            }
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
