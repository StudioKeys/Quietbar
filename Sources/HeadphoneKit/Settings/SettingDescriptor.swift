public enum SettingSection: Hashable, Sendable, CaseIterable {
    case noise
    case sound
    case smart
}

public struct ChoiceOption: Hashable, Sendable {
    public let id: String
    public let title: String
    public let symbol: String?

    public init(id: String, title: String, symbol: String? = nil) {
        self.id = id
        self.title = title
        self.symbol = symbol
    }
}

public enum ChoiceStyle: Hashable, Sendable {
    case menu
    case segmented
    case modeButtons
}

public enum LevelStyle: Hashable, Sendable {
    case slider
    case balance
}

public enum SettingKind: Hashable, Sendable {
    case toggle
    case choice([ChoiceOption], style: ChoiceStyle)
    case level(ClosedRange<Int>, style: LevelStyle)
}

public enum Condition: Hashable, Sendable {
    case equals(SettingID, SettingValue)

    public func isSatisfied(by state: DeviceState) -> Bool {
        switch self {
        case .equals(let id, let value): state[id] == value
        }
    }
}

public struct SettingDescriptor: Hashable, Sendable {
    public let id: SettingID
    public let title: String
    public let symbol: String?
    public let kind: SettingKind
    public let section: SettingSection
    public let visibleWhen: Condition?

    public init(
        id: SettingID,
        title: String,
        symbol: String? = nil,
        kind: SettingKind,
        section: SettingSection,
        visibleWhen: Condition? = nil
    ) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.kind = kind
        self.section = section
        self.visibleWhen = visibleWhen
    }

    public func isVisible(in state: DeviceState) -> Bool {
        visibleWhen?.isSatisfied(by: state) ?? true
    }
}
