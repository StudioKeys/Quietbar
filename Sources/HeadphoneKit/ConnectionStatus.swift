public enum ConnectionStatus: Sendable, Hashable {
    case idle
    case searching
    case connected
    case disconnectedByUser
    case unavailable(BluetoothIssue)
    case retrying(after: Duration, phoneHint: Bool)
}
