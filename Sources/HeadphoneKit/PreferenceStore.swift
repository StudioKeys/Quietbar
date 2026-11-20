import Foundation
import Synchronization

public enum ExperimentalWritePreference {
    public static let key = "experimentalHeadphoneWritesEnabled"
}

public protocol PreferenceStore: Sendable {
    func bool(forKey key: String) -> Bool?
    func set(_ value: Bool, forKey key: String)
    func string(forKey key: String) -> String?
    func set(_ value: String, forKey key: String)
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

    public func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    public func set(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}

public final class InMemoryPreferenceStore: PreferenceStore {
    private let bools = Mutex<[String: Bool]>([:])
    private let strings = Mutex<[String: String]>([:])

    public init() {}

    public func bool(forKey key: String) -> Bool? {
        bools.withLock { $0[key] }
    }

    public func set(_ value: Bool, forKey key: String) {
        bools.withLock { $0[key] = value }
    }

    public func string(forKey key: String) -> String? {
        strings.withLock { $0[key] }
    }

    public func set(_ value: String, forKey key: String) {
        strings.withLock { $0[key] = value }
    }
}
