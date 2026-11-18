import HeadphoneKit
import Observation
import os

struct SectionModel: Identifiable, Equatable {
    let section: SettingSection
    let settings: [SettingDescriptor]

    var id: SettingSection { section }

    var title: String {
        switch section {
        case .noise: "Noise control"
        case .sound: "Sound"
        case .smart: "Smart features"
        }
    }
}

@MainActor
@Observable
final class HeadphoneViewModel {
    private static let logger = Logger(subsystem: "dev.studiokeys.quietbar", category: "HeadphoneViewModel")

    private(set) var snapshot = DeviceSnapshot.initial
    private(set) var pending: Set<SettingID> = []
    let model: DeviceModel
    private let controller: any HeadphoneControlling

    init(controller: any HeadphoneControlling, model: DeviceModel) {
        self.controller = controller
        self.model = model
    }

    var deviceName: String { snapshot.deviceName ?? model.name }
    var icon: MenuBarIcon { MenuBarIcon.make(for: snapshot, model: model) }
    var statusText: String { StatusText.describe(snapshot.status, deviceName: model.name) }
    var showsConnectButton: Bool { [.disconnectedByUser, .waiting].contains(snapshot.status) }
    var isConnected: Bool { snapshot.status == .connected }
    var battery: Battery? { snapshot.state.battery }
    var showsControls: Bool { isConnected || snapshot.state != .empty }
    var canEdit: Bool { isConnected }

    var sections: [SectionModel] {
        SettingSection.allCases.compactMap { section in
            let visible = model.settings.filter { $0.section == section && $0.isVisible(in: snapshot.state) }
            return visible.isEmpty ? nil : SectionModel(section: section, settings: visible)
        }
    }

    static func balanceText(_ offset: Int) -> String {
        switch offset {
        case 0: "0"
        case ..<0: "L \(-offset)"
        default: "R \(offset)"
        }
    }

    func value(for id: SettingID) -> SettingValue? {
        snapshot.state[id]
    }

    func isOn(_ id: SettingID) -> Bool {
        value(for: id) == .bool(true)
    }

    func run() async {
        async let observing: Void = observe()
        await controller.start()
        await observing
    }

    func start() async {
        await controller.start()
    }

    func stop() async {
        await controller.stop()
    }

    func connectNow() async {
        await controller.userConnect()
    }

    func observe() async {
        for await next in controller.snapshots {
            snapshot = next
        }
    }

    @discardableResult
    func set(_ id: SettingID, _ value: SettingValue) -> Task<Void, Never>? {
        guard !pending.contains(id), self.value(for: id) != value else { return nil }
        pending.insert(id)
        let controller = controller
        return Task {
            do throws(ApplyError) {
                try await controller.apply(SettingChange(id: id, value: value))
            } catch {
                Self.logger.notice("\(id.rawValue, privacy: .public) not applied: \(error.message, privacy: .public)")
            }
            pending.remove(id)
        }
    }

    @discardableResult
    func menuOpened() -> Task<Void, Never>? {
        guard isConnected else { return nil }
        let controller = controller
        return Task { await controller.refresh() }
    }

    @discardableResult
    func connect() -> Task<Void, Never> {
        let controller = controller
        return Task { await controller.userConnect() }
    }

    @discardableResult
    func disconnect() -> Task<Void, Never> {
        let controller = controller
        return Task { await controller.userDisconnect() }
    }
}
