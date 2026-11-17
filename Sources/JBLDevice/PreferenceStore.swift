import Foundation
import Synchronization

public protocol PreferenceStore: Sendable {
    func bool(forKey key: String) -> Bool?
    func set(_ value: Bool, forKey key: String)
}

public struct UserDefaultsStore: PreferenceStore {
    private let suiteName: String?

    public init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public func bool(forKey key: String) -> Bool? {
        defaults.object(forKey: key) as? Bool
    }

    public func set(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}

public final class InMemoryPreferenceStore: PreferenceStore {
    private let values = Mutex<[String: Bool]>([:])

    public init() {}

    public func bool(forKey key: String) -> Bool? {
        values.withLock { $0[key] }
    }

    public func set(_ value: Bool, forKey key: String) {
        values.withLock { $0[key] = value }
    }
}
