import HeadphoneKit
import Observation

@MainActor
@Observable
final class ActiveDevice {
    static let selectedKey = "selectedDevice"
    static let legacyDeviceID = "jbl.live770nc"

    let entries: [DeviceEntry]
    private(set) var selected: DeviceEntry
    private(set) var viewModel: HeadphoneViewModel
    private let preferences: any PreferenceStore
    private let pairedDeviceNames: @MainActor () -> [String]
    private var observing: Task<Void, Never>?

    init(
        entries: [DeviceEntry], preferences: any PreferenceStore,
        pairedDeviceNames: @escaping @MainActor () -> [String] = { [] }
    ) {
        precondition(!entries.isEmpty, "Quietbar needs at least one supported device")
        Self.migrateLegacyChoice(in: preferences)
        let persisted = preferences.string(forKey: Self.selectedKey)
        let paired = pairedDeviceNames()
        let selected =
            entries.first { $0.id == persisted }
            ?? entries.first { Self.isPaired($0, among: paired) }
            ?? entries[0]
        self.entries = entries
        self.preferences = preferences
        self.pairedDeviceNames = pairedDeviceNames
        self.selected = selected
        self.viewModel = Self.makeViewModel(for: selected)
    }

    /// Headphones the user actually owns: ones Quietbar has connected to before or that are paired with this Mac.
    var switchableEntries: [DeviceEntry] {
        let paired = pairedDeviceNames()
        return entries.filter { entry in
            entry.id == selected.id || hasConnected(entry) || Self.isPaired(entry, among: paired)
        }
    }

    var showsSwitcher: Bool { switchableEntries.count > 1 }

    private func hasConnected(_ entry: DeviceEntry) -> Bool {
        preferences.string(forKey: DeviceSession.identityKey(for: entry.id)).flatMap(DeviceIdentity.decode) != nil
    }

    private static func isPaired(_ entry: DeviceEntry, among names: [String]) -> Bool {
        names.contains { $0.localizedCaseInsensitiveContains(entry.model.nameFragment) }
    }

    func displayName(for entry: DeviceEntry) -> String {
        if entry.id == selected.id { return viewModel.deviceName }
        let stored = preferences.string(forKey: DeviceSession.identityKey(for: entry.id))
        return stored.flatMap(DeviceIdentity.decode)?.displayName ?? entry.name
    }

    func start() async {
        observe(viewModel)
        await viewModel.start()
    }

    func select(_ id: String) async {
        guard id != selected.id, let entry = entries.first(where: { $0.id == id }) else { return }
        let previous = viewModel
        let next = Self.makeViewModel(for: entry)
        preferences.set(id, forKey: Self.selectedKey)
        selected = entry
        viewModel = next
        observe(next)
        await previous.stop()
        await next.connectNow()
    }

    private func observe(_ model: HeadphoneViewModel) {
        observing?.cancel()
        observing = Task { await model.observe() }
    }

    private static func makeViewModel(for entry: DeviceEntry) -> HeadphoneViewModel {
        HeadphoneViewModel(controller: entry.makeController(entry.id), model: entry.model)
    }

    private static func migrateLegacyChoice(in preferences: any PreferenceStore) {
        let key = DeviceSession.connectionKey(for: legacyDeviceID)
        guard preferences.bool(forKey: key) == nil,
            let legacy = preferences.bool(forKey: DeviceSession.wantsConnectionKey)
        else { return }
        preferences.set(legacy, forKey: key)
    }
}
