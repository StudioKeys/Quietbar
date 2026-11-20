import IOBluetooth

public enum PairedDevices {
    /// Names of the Bluetooth Classic devices paired with this Mac.
    @MainActor
    public static func names() -> [String] {
        (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []).compactMap(\.name)
    }
}
