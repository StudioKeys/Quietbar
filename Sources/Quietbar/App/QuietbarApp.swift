import JBLBluetooth
import JBLDevice
import SwiftUI

@main
struct QuietbarApp: App {
    @State private var viewModel = HeadphoneViewModel(
        controller: HeadphoneSession(transport: CoreBluetoothTransport(), preferences: UserDefaultsStore())
    )

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(viewModel: viewModel)
        } label: {
            MenuBarLabel(icon: viewModel.icon)
                .task { await viewModel.run() }
        }
        .menuBarExtraStyle(.window)
    }
}
