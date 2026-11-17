public enum BluetoothIssue: Sendable, Hashable {
    case poweredOff
    case unauthorized
    case unsupported
}

public enum LinkEvent: Sendable, Hashable {
    case connected
    case disconnected
    case bluetoothUnavailable(BluetoothIssue)
    case bluetoothReady
}

public enum TransportError: Error, Sendable, Hashable {
    case notFound
    case connectFailed
    case notConnected
    case writeFailed
    case bluetoothUnavailable(BluetoothIssue)
}
