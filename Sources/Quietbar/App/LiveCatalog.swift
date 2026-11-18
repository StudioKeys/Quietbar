import BluetoothLE
import ClassicBluetooth
import HeadphoneKit
import JBLDriver

enum LiveCatalog {
    static func entries(preferences: any PreferenceStore) -> [DeviceEntry] {
        let jbl = JBLLive770NCDriver()
        return [
            DeviceEntry(id: "jbl.live770nc", model: jbl.model) { deviceID in
                DeviceSession(
                    driver: jbl,
                    transport: CoreBluetoothTransport(
                        profile: JBLLive770NCDriver.gatt, nameFragment: jbl.model.nameFragment),
                    preferences: preferences,
                    watcher: IOBluetoothConnectionWatcher(),
                    deviceID: deviceID
                )
            }
        ]
    }
}
