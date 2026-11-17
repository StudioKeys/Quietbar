import Foundation
import Testing

@testable import HeadphoneKit

struct UserDefaultsStoreTests {
    private let suiteName = "dev.studiokeys.quietbar.tests.\(UUID().uuidString)"

    @Test func storesAndReadsBackBool() {
        let store = UserDefaultsStore(suiteName: suiteName)
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let before = store.bool(forKey: "wantsConnection")
        store.set(false, forKey: "wantsConnection")

        #expect(before == nil)
        #expect(store.bool(forKey: "wantsConnection") == false)
    }
}
