import ClassicBluetooth
import HeadphoneKit
import SwiftUI

@main
struct QuietbarApp: App {
    @State private var activeDevice = ActiveDevice(
        entries: LiveCatalog.entries(preferences: UserDefaultsStore()),
        preferences: UserDefaultsStore(),
        pairedDeviceNames: PairedDevices.names
    )

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(activeDevice: activeDevice)
        } label: {
            MenuBarLabel(icon: activeDevice.viewModel.icon)
                .task { await activeDevice.start() }
        }
        .menuBarExtraStyle(.window)
    }
}
