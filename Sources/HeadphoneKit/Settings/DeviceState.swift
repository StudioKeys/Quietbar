public struct Battery: Hashable, Sendable {
    public let percent: Int
    public let isCharging: Bool

    public init(percent: Int, isCharging: Bool) {
        self.percent = percent
        self.isCharging = isCharging
    }
}

public enum DeviceUpdate: Hashable, Sendable {
    case setting(SettingID, SettingValue)
    case battery(Battery)
}

public struct DeviceState: Hashable, Sendable {
    public static let empty = DeviceState(values: [:], battery: nil)

    public let battery: Battery?
    private let values: [SettingID: SettingValue]

    private init(values: [SettingID: SettingValue], battery: Battery?) {
        self.values = values
        self.battery = battery
    }

    public subscript(id: SettingID) -> SettingValue? {
        values[id]
    }

    public func applying(_ updates: [DeviceUpdate]) -> DeviceState {
        updates.reduce(self) { state, update in
            switch update {
            case .setting(let id, let value):
                DeviceState(values: state.values.merging([id: value]) { _, new in new }, battery: state.battery)
            case .battery(let battery):
                DeviceState(values: state.values, battery: battery)
            }
        }
    }
}
