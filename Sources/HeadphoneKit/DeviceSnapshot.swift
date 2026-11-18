public struct DeviceSnapshot: Sendable, Hashable {
    public static let initial = DeviceSnapshot(status: .idle, state: .empty, lastError: nil)

    public let status: ConnectionStatus
    public let state: DeviceState
    public let lastError: String?
    public let deviceName: String?

    public init(status: ConnectionStatus, state: DeviceState, lastError: String?, deviceName: String? = nil) {
        self.status = status
        self.state = state
        self.lastError = lastError
        self.deviceName = deviceName
    }

    func with(status: ConnectionStatus) -> DeviceSnapshot {
        DeviceSnapshot(status: status, state: state, lastError: lastError, deviceName: deviceName)
    }

    func with(state: DeviceState) -> DeviceSnapshot {
        DeviceSnapshot(status: status, state: state, lastError: lastError, deviceName: deviceName)
    }

    func with(lastError: String?) -> DeviceSnapshot {
        DeviceSnapshot(status: status, state: state, lastError: lastError, deviceName: deviceName)
    }

    func with(deviceName: String?) -> DeviceSnapshot {
        DeviceSnapshot(status: status, state: state, lastError: lastError, deviceName: deviceName)
    }
}
