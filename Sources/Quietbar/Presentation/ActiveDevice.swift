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
    private var observing: Task<Void, Never>?

    init(entries: [DeviceEntry], preferences: any PreferenceStore) {
        precondition(!entries.isEmpty, "Quietbar needs at least one supported device")
        Self.migrateLegacyChoice(in: preferences)
        let persisted = preferences.string(forKey: Self.selectedKey)
        let selected = entries.first { $0.id == persisted } ?? entries[0]
        self.entries = entries
        self.preferences = preferences
        self.selected = selected
        self.viewModel = Self.makeViewModel(for: selected)
    }

    var showsSwitcher: Bool { entries.count > 1 }

    func start() async {
        observe(viewModel)
        await viewModel.start()
    }

    func select(_ id: String) async {
        guard id != selected.id, let entry = entries.first(where: { $0.id == id }) else { return }
        observing?.cancel()
        await viewModel.stop()
        preferences.set(id, forKey: Self.selectedKey)
        let next = Self.makeViewModel(for: entry)
        selected = entry
        viewModel = next
        observe(next)
        await next.connectNow()
    }

    private func observe(_ model: HeadphoneViewModel) {
        observing?.cancel()
        observing = Task { await model.observe() }
    }

    private static func makeViewModel(for entry: DeviceEntry) -> HeadphoneViewModel {
        HeadphoneViewModel(controller: entry.makeController(entry.connectionPreferenceKey), model: entry.model)
    }

    private static func migrateLegacyChoice(in preferences: any PreferenceStore) {
        let key = "\(DeviceSession.wantsConnectionKey).\(legacyDeviceID)"
        guard preferences.bool(forKey: key) == nil,
            let legacy = preferences.bool(forKey: DeviceSession.wantsConnectionKey)
        else { return }
        preferences.set(legacy, forKey: key)
    }
}
