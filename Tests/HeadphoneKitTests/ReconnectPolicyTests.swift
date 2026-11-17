import Testing

@testable import HeadphoneKit

struct ReconnectPolicyTests {
    @Test func policyDelaysFollowSchedule() {
        let delays = (1...6).map(ReconnectPolicy.standard.delay(afterFailures:))

        #expect(delays == [.seconds(1), .seconds(2), .seconds(5), .seconds(10), .seconds(30), .seconds(30)])
    }

    @Test func zeroFailuresUsesFirstDelay() {
        #expect(ReconnectPolicy.standard.delay(afterFailures: 0) == .seconds(1))
    }

    @Test func inMemoryStoreStartsEmptyAndRemembers() {
        let store = InMemoryPreferenceStore()

        let before = store.bool(forKey: "k")
        store.set(false, forKey: "k")

        #expect(before == nil)
        #expect(store.bool(forKey: "k") == false)
    }
}
