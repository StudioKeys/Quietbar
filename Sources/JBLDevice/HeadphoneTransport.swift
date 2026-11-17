import JBLProtocol

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

public protocol HeadphoneTransport: Sendable {
    var incoming: AsyncStream<Frame> { get }
    var events: AsyncStream<LinkEvent> { get }
    func connect() async throws(TransportError)
    func disconnect() async
    func send(_ frame: Frame) async throws(TransportError)
}
