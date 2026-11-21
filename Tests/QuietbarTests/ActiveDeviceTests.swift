import HeadphoneKit
import Testing

@testable import Quietbar

@MainActor
struct ActiveDeviceTests {
    private final class Controllers: @unchecked Sendable {
        var made: [String: FakeController] = [:]
        var deviceIDs: [String: String] = [:]
        var makeCount: [String: Int] = [:]
        var holdsStop = false
    }

    private let controllers = Controllers()

    private func entry(_ id: String) -> DeviceEntry {
        let controllers = controllers
        return DeviceEntry(id: id, model: Fixtures.model) { deviceID in
            let controller = FakeController(holdsStop: controllers.holdsStop)
            controllers.made[id] = controller
            controllers.makeCount[id, default: 0] += 1
            controllers.deviceIDs[id] = deviceID
            return controller
        }
    }

    private func device(
        _ ids: [String] = ["jbl.live770nc", "moto.budsplus"], store: InMemoryPreferenceStore,
        paired: [String] = []
    ) -> ActiveDevice {
        ActiveDevice(entries: ids.map(entry), preferences: store, pairedDeviceNames: { paired })
    }

    private func entry(_ id: String, fragment: String) -> DeviceEntry {
        let base = Fixtures.model
        let model = DeviceModel(name: id, nameFragment: fragment, link: base.link, settings: base.settings)
        return DeviceEntry(id: id, model: model) { _ in FakeController() }
    }

    @Test func switcherListsOnlySelectedPairedOrPreviouslyConnectedHeadphones() {
        let store = InMemoryPreferenceStore()
        store.set(
            DeviceIdentity(name: "moto buds+", linkID: "x", classicAddress: nil).encoded,
            forKey: DeviceSession.identityKey(for: "moto"))
        let active = ActiveDevice(
            entries: [
                entry("cmf", fragment: "CMF Headphone Pro"), entry("jbl", fragment: "Live 770NC"),
                entry("moto", fragment: "moto buds"), entry("sony", fragment: "WH-1000XM5"),
            ],
            preferences: store, pairedDeviceNames: { ["Hariharan's CMF Headphone Pro"] })

        #expect(active.switchableEntries.map(\.id) == ["cmf", "moto"])
        #expect(active.showsSwitcher)
    }

    @Test func pairedDevicesAreReadOnceAndRefreshedOnDemand() {
        var queries = 0
        var paired = ["JBL LIVE 770NC"]
        let active = ActiveDevice(
            entries: [entry("jbl", fragment: "Live 770NC"), entry("cmf", fragment: "CMF Headphone Pro")],
            preferences: InMemoryPreferenceStore(),
            pairedDeviceNames: {
                queries += 1
                return paired
            })

        _ = active.switchableEntries
        _ = active.showsSwitcher
        #expect(queries == 1)

        paired.append("CMF Headphone Pro")
        active.refreshPairedDevices()

        #expect(queries == 2)
        #expect(active.switchableEntries.map(\.id) == ["jbl", "cmf"])
    }

    @Test func singleOwnedHeadphoneHidesSwitcher() {
        let active = ActiveDevice(
            entries: [entry("cmf", fragment: "CMF Headphone Pro"), entry("jbl", fragment: "Live 770NC")],
            preferences: InMemoryPreferenceStore(), pairedDeviceNames: { ["JBL LIVE 770NC"] })

        #expect(active.selected.id == "jbl")
        #expect(!active.showsSwitcher)
    }

    @Test func firstLaunchSelectsFirstEntry() {
        let active = device(store: InMemoryPreferenceStore())

        #expect(active.selected.id == "jbl.live770nc")
        #expect(controllers.deviceIDs["jbl.live770nc"] == "jbl.live770nc")
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

    @Test func switcherNamesUseRememberedBluetoothName() {
        let store = InMemoryPreferenceStore()
        let identity = DeviceIdentity(
            name: "JBL Live 770NC-LE", linkID: "LINK-1", classicAddress: "AA", classicName: "Jis Cans")
        store.set(identity.encoded, forKey: DeviceSession.identityKey(for: "moto.budsplus"))
        let active = device(store: store)

        #expect(active.displayName(for: active.entries[1]) == "Jis Cans")
        #expect(active.displayName(for: active.entries[0]) == Fixtures.model.name)
    }

    @Test func concurrentSelectsBuildOneSession() async throws {
        controllers.holdsStop = true
        let active = device(store: InMemoryPreferenceStore())
        let old = controllers.made["jbl.live770nc"]

        let first = Task { await active.select("moto.budsplus") }
        let second = Task { await active.select("moto.budsplus") }
        try await waitUntil { await old?.stopCount == 1 }
        await old?.releaseStop()
        await first.value
        await second.value

        #expect(controllers.makeCount["moto.budsplus"] == 1)
        #expect(await old?.stopCount == 1)
    }

    @Test func switcherHiddenUntilASecondHeadphoneIsOwned() {
        #expect(!device(store: InMemoryPreferenceStore()).showsSwitcher)
        #expect(!device(["jbl.live770nc"], store: InMemoryPreferenceStore()).showsSwitcher)
    }
}
