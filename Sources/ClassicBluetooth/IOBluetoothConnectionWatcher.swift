import HeadphoneKit
import IOBluetooth
import os

// IOBluetooth delivers connect notifications on the main run loop, which owns all mutable state here.
public final class IOBluetoothConnectionWatcher: NSObject, ConnectionWatcher, @unchecked Sendable {
    private static let logger = Logger.quietbar("ConnectionWatcher")

    public let connections: AsyncStream<ClassicConnection>
    private let continuation: AsyncStream<ClassicConnection>.Continuation
    private var registration: IOBluetoothUserNotification?

    @MainActor
    public override init() {
        (connections, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(8))
        super.init()
        registration = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnected(_:device:))
        )
        for device in Self.connectedDevices() {
            report(device)
        }
    }

    deinit {
        registration?.unregister()
        continuation.finish()
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        report(device)
    }

    private func report(_ device: IOBluetoothDevice) {
        guard device.isPaired(), let address = device.addressString else { return }
        let name = device.name ?? address
        Self.logger.debug("Classic device connected: \(name, privacy: .public)")
        continuation.yield(ClassicConnection(name: name, address: address))
    }

    private static func connectedDevices() -> [IOBluetoothDevice] {
        let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        return paired.filter { $0.isConnected() }
    }
}
