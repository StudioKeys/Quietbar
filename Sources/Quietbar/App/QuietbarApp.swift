import BluetoothLE
import HeadphoneKit
import JBLDriver
import SwiftUI

@main
struct QuietbarApp: App {
    @State private var viewModel: HeadphoneViewModel

    init() {
        let driver = JBLLive770NCDriver()
        let session = DeviceSession(
            driver: driver,
            transport: CoreBluetoothTransport(profile: driver.model.gatt),
            preferences: UserDefaultsStore()
        )
        _viewModel = State(initialValue: HeadphoneViewModel(controller: session, model: driver.model))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(viewModel: viewModel)
        } label: {
            MenuBarLabel(icon: viewModel.icon)
                .task { await viewModel.run() }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
