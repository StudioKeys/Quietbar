public struct DeviceSnapshot: Sendable, Hashable {
    public static let initial = DeviceSnapshot(status: .idle, state: .empty, lastError: nil)

    public let status: ConnectionStatus
    public let state: DeviceState
    public let lastError: String?

    public init(status: ConnectionStatus, state: DeviceState, lastError: String?) {
        self.status = status
        self.state = state
        self.lastError = lastError
    }

    func with(status: ConnectionStatus) -> DeviceSnapshot {
        DeviceSnapshot(status: status, state: state, lastError: lastError)
    }

    func with(state: DeviceState) -> DeviceSnapshot {
        DeviceSnapshot(status: status, state: state, lastError: lastError)
    }

    func with(lastError: String?) -> DeviceSnapshot {
        DeviceSnapshot(status: status, state: state, lastError: lastError)
    }
}
