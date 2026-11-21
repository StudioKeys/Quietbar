import BluetoothLE
import CMFDriver
import ClassicBluetooth
import HeadphoneKit
import JBLDriver
import MotoDriver

enum LiveCatalog {
    static func entries(preferences: any PreferenceStore) -> [DeviceEntry] {
        let jbl = JBLLive770NCDriver()
        let moto = MotoBudsPlusDriver()
        let cmf = CMFHeadphonesProDriver()
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
            },
            DeviceEntry(id: "moto.budsplus", model: moto.model) { deviceID in
                DeviceSession(
                    driver: moto,
                    transport: RFCOMMTransport(
                        serviceUUID: MotoBudsPlusDriver.serviceUUID, nameFragment: moto.model.nameFragment),
                    preferences: preferences,
                    watcher: IOBluetoothConnectionWatcher(),
                    deviceID: deviceID
                )
            },
            DeviceEntry(id: "cmf.headphonespro", model: cmf.model) { deviceID in
                DeviceSession(
                    driver: cmf,
                    transport: RFCOMMTransport(
                        serviceUUID: CMFHeadphonesProDriver.serviceUUID, nameFragment: cmf.model.nameFragment),
                    preferences: preferences,
                    watcher: IOBluetoothConnectionWatcher(),
                    deviceID: deviceID
                )
            },
        ]
    }
}
