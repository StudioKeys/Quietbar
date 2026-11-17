public struct SettingID: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

public enum SettingValue: Hashable, Sendable {
    case bool(Bool)
    case choice(String)
    case level(Int)
}

public struct SettingChange: Hashable, Sendable {
    public let id: SettingID
    public let value: SettingValue

    public init(id: SettingID, value: SettingValue) {
        self.id = id
        self.value = value
    }
}
