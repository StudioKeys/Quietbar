import JBLDevice
import JBLProtocol
import Observation
import os

@MainActor
@Observable
final class HeadphoneViewModel {
    private static let logger = Logger(subsystem: "dev.studiokeys.quietbar", category: "HeadphoneViewModel")

    private(set) var snapshot = SessionSnapshot.initial
    private(set) var pending: Set<ReplyKind> = []
    private let controller: any HeadphoneControlling

    init(controller: any HeadphoneControlling) {
        self.controller = controller
    }

    var icon: MenuBarIcon { MenuBarIcon.make(for: snapshot) }
    var statusText: String { StatusText.describe(snapshot.status) }
    var isConnected: Bool { snapshot.status == .connected }
    var state: HeadphoneState { snapshot.state }

    func observe() async {
        for await next in controller.snapshots {
            snapshot = next
        }
    }

    @discardableResult
    func select(_ mode: NoiseMode) -> Task<Void, Never>? {
        submit(.setNoiseMode(mode))
    }

    @discardableResult
    func setAmbientLevel(_ value: Int) -> Task<Void, Never>? {
        AmbientLevel(value).flatMap { submit(.setAmbientLevel($0)) }
    }

    @discardableResult
    func select(_ preset: EqPreset) -> Task<Void, Never>? {
        submit(.setEqPreset(preset))
    }

    @discardableResult
    func setSpatial(_ setting: SpatialSetting) -> Task<Void, Never>? {
        submit(.setSpatial(setting))
    }

    @discardableResult
    func setLowVolumeEq(_ isOn: Bool) -> Task<Void, Never>? {
        submit(.setLowVolumeEq(isOn))
    }

    @discardableResult
    func setBalance(offset: Int) -> Task<Void, Never>? {
        Balance(offset: offset).flatMap { submit(.setBalance($0)) }
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

    private func submit(_ command: Command) -> Task<Void, Never>? {
        let kind = command.expectedReply
        guard !pending.contains(kind) else { return nil }
        pending.insert(kind)
        let controller = controller
        return Task {
            do {
                try await controller.apply(command)
            } catch {
                Self.logger.notice("Change not confirmed: \(String(describing: error), privacy: .public)")
            }
            pending.remove(kind)
        }
    }
}
