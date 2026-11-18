public struct BatteryLevel: Hashable, Sendable {
    public let percent: Int
    public let isCharging: Bool

    public init(percent: Int, isCharging: Bool) {
        self.percent = percent
        self.isCharging = isCharging
    }
}

public struct Battery: Hashable, Sendable {
    public let percent: Int
    public let isCharging: Bool
    public let left: BatteryLevel?
    public let right: BatteryLevel?
    public let caseLevel: BatteryLevel?

    public init(percent: Int, isCharging: Bool) {
        self.init(percent: percent, isCharging: isCharging, left: nil, right: nil, caseLevel: nil)
    }

    private init(percent: Int, isCharging: Bool, left: BatteryLevel?, right: BatteryLevel?, caseLevel: BatteryLevel?) {
        self.percent = percent
        self.isCharging = isCharging
        self.left = left
        self.right = right
        self.caseLevel = caseLevel
    }

    public static func buds(left: BatteryLevel?, right: BatteryLevel?, caseLevel: BatteryLevel?) -> Battery? {
        let known = [left, right].compactMap { $0 }
        guard let lowest = known.map(\.percent).min() else { return nil }
        return Battery(
            percent: lowest,
            isCharging: known.contains { $0.isCharging },
            left: left,
            right: right,
            caseLevel: caseLevel
        )
    }

    public var hasComponents: Bool { left != nil || right != nil }
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
