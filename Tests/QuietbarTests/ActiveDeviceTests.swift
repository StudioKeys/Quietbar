import HeadphoneKit
import Testing

@testable import Quietbar

@MainActor
struct ActiveDeviceTests {
    private final class Controllers: @unchecked Sendable {
        var made: [String: FakeController] = [:]
        var keys: [String: String] = [:]
    }

    private let controllers = Controllers()

    private func entry(_ id: String) -> DeviceEntry {
        let controllers = controllers
        return DeviceEntry(id: id, model: Fixtures.model) { key in
            let controller = FakeController()
            controllers.made[id] = controller
            controllers.keys[id] = key
            return controller
        }
    }

    private func device(_ ids: [String] = ["jbl.live770nc", "moto.budsplus"], store: InMemoryPreferenceStore)
        -> ActiveDevice
    {
        ActiveDevice(entries: ids.map(entry), preferences: store)
    }

    @Test func firstLaunchSelectsFirstEntry() {
        let active = device(store: InMemoryPreferenceStore())

        #expect(active.selected.id == "jbl.live770nc")
        #expect(controllers.keys["jbl.live770nc"] == "wantsConnection.jbl.live770nc")
    }

    @Test func selectionPersistsAcrossLaunch() async {
        let store = InMemoryPreferenceStore()
        await device(store: store).select("moto.budsplus")

        let relaunched = device(store: store)

        #expect(relaunched.selected.id == "moto.budsplus")
    }

    @Test func selectStopsOldAndConnectsNew() async {
        let active = device(store: InMemoryPreferenceStore())
        let old = controllers.made["jbl.live770nc"]

        await active.select("moto.budsplus")

        #expect(await old?.stopCount == 1)
        #expect(await controllers.made["moto.budsplus"]?.connectCount == 1)
        #expect(active.selected.id == "moto.budsplus")
    }

    @Test func selectingCurrentDeviceDoesNothing() async {
        let active = device(store: InMemoryPreferenceStore())
        let current = controllers.made["jbl.live770nc"]

        await active.select("jbl.live770nc")

        #expect(await current?.stopCount == 0)
        #expect(await current?.connectCount == 0)
    }

    @Test func unknownPersistedIdFallsBackToFirst() {
        let store = InMemoryPreferenceStore()
        store.set("sony.xm5", forKey: ActiveDevice.selectedKey)

        #expect(device(store: store).selected.id == "jbl.live770nc")
    }

    @Test func legacyDisconnectMigratesToJBL() {
        let store = InMemoryPreferenceStore()
        store.set(false, forKey: DeviceSession.wantsConnectionKey)

        _ = device(store: store)

        #expect(store.bool(forKey: "wantsConnection.jbl.live770nc") == false)
    }

    @Test func showsSwitcherOnlyWithSeveralEntries() {
        #expect(device(store: InMemoryPreferenceStore()).showsSwitcher)
        #expect(!device(["jbl.live770nc"], store: InMemoryPreferenceStore()).showsSwitcher)
    }
}
