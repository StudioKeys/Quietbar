import JBLProtocol

public enum ConnectionStatus: Sendable, Hashable {
    case idle
    case searching
    case connected
    case disconnectedByUser
    case unavailable(BluetoothIssue)
    case retrying(after: Duration, phoneHint: Bool)
}

public struct SessionSnapshot: Sendable, Hashable {
    public static let initial = SessionSnapshot(status: .idle, state: .empty, lastError: nil)

    public let status: ConnectionStatus
    public let state: HeadphoneState
    public let lastError: String?

    public init(status: ConnectionStatus, state: HeadphoneState, lastError: String?) {
        self.status = status
        self.state = state
        self.lastError = lastError
    }

    func with(status: ConnectionStatus) -> SessionSnapshot {
        SessionSnapshot(status: status, state: state, lastError: lastError)
    }

    func with(state: HeadphoneState) -> SessionSnapshot {
        SessionSnapshot(status: status, state: state, lastError: lastError)
    }

    func with(lastError: String?) -> SessionSnapshot {
        SessionSnapshot(status: status, state: state, lastError: lastError)
    }
}
