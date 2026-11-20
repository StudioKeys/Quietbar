import CMFProtocol
import Foundation
import HeadphoneKit

public struct CMFHeadphonesProDriver: DeviceDriver {
    public static let serviceUUID = UUID(uuidString: "AEAC4A03-DFF5-498F-843A-34487CF133EB")!

    public let model = DeviceModel(
        name: "CMF Headphone Pro",
        nameFragment: "CMF Headphone Pro",
        link: .rfcomm(serviceUUID: serviceUUID),
        settings: CMFSetting.descriptors
    )

    private let sequence = CMFSequence()
    private let writesEnabled: @Sendable () -> Bool

    public init(writesEnabled: @escaping @Sendable () -> Bool = { false }) {
        self.writesEnabled = writesEnabled
    }

    public var handshakeRequests: [Data] {
        [
            command(.getProtocolVersion),
            command(.getBattery),
            command(.getNoiseControl, payload: [3]),
            command(.getEQPreset),
        ]
    }

    public var refreshRequests: [Data] {
        CMFSetting.descriptors.compactMap { confirmingRequest(for: $0.id) } + [command(.getBattery)]
    }

    public func requests(for change: SettingChange, current: DeviceState) -> [Data]? {
        guard writesEnabled() else { return nil }
        switch (change.id, change.value) {
        case (CMFSetting.noiseMode, .choice(let id)):
            return CMFNoiseMode(rawValue: UInt8(id) ?? 255)
                .map { [command(.setNoiseControl, payload: [1, $0.rawValue, 0])] }
        case (CMFSetting.eqPreset, .choice(let id)):
            return CMFEQPreset(rawValue: UInt8(id) ?? 255).map { [command(.setEQPreset, payload: [$0.rawValue])] }
        case (CMFSetting.lowLag, .bool(let enabled)):
            return [command(.setLowLag, payload: [enabled ? 1 : 2])]
        case (CMFSetting.spatialSound, .bool(let enabled)):
            return [command(.setSpatialAudio, payload: [enabled ? 1 : 0])]
        case (CMFSetting.dualConnection, .bool(let enabled)):
            return [command(.setDualConnection, payload: [enabled ? 1 : 0])]
        default:
            return nil
        }
    }

    public func confirmingRequest(for setting: SettingID) -> Data? {
        switch setting {
        case CMFSetting.noiseMode: command(.getNoiseControl, payload: [3])
        case CMFSetting.eqPreset: command(.getEQPreset)
        case CMFSetting.lowLag: command(.getLowLag)
        case CMFSetting.spatialSound: command(.getSpatialAudio)
        case CMFSetting.dualConnection: command(.getDualConnection)
        case .battery: command(.getBattery)
        default: nil
        }
    }

    public func updates(from packet: Data) -> [DeviceUpdate] {
        guard let frame = try? CMFFrame.decode(packet), frame.isResponseOK else { return [] }
        switch frame.command {
        case CMFCommand.getBattery.rawValue, CMFCommand.getBattery.responseCommand,
            CMFCommand.batteryChanged.rawValue, CMFCommand.batteryChanged.responseCommand:
            return batteryUpdates([UInt8](frame.payload))
        case CMFCommand.getNoiseControl.rawValue, CMFCommand.getNoiseControl.responseCommand,
            CMFCommand.noiseControlChanged.rawValue, CMFCommand.noiseControlChanged.responseCommand:
            return noiseUpdates([UInt8](frame.payload))
        case CMFCommand.getEQPreset.rawValue, CMFCommand.getEQPreset.responseCommand:
            return choiceUpdate(
                CMFSetting.eqPreset, CMFEQPreset(rawValue: frame.payload.first ?? 255)?.rawValue)
        case CMFCommand.getLowLag.rawValue, CMFCommand.getLowLag.responseCommand,
            CMFCommand.lowLagChanged.rawValue, CMFCommand.lowLagChanged.responseCommand:
            return frame.payload.first.map { [.setting(CMFSetting.lowLag, .bool($0 == 1))] } ?? []
        case CMFCommand.getSpatialAudio.rawValue, CMFCommand.getSpatialAudio.responseCommand:
            return frame.payload.first.map { [.setting(CMFSetting.spatialSound, .bool($0 != 0))] } ?? []
        case CMFCommand.getDualConnection.rawValue, CMFCommand.getDualConnection.responseCommand:
            return frame.payload.first.map { [.setting(CMFSetting.dualConnection, .bool($0 != 0))] } ?? []
        default:
            return []
        }
    }

    public func isReady(_ state: DeviceState) -> Bool {
        state[CMFSetting.noiseMode] != nil && state[CMFSetting.eqPreset] != nil
    }

    public func makeFramer() -> any PacketFramer {
        CMFFramer()
    }

    private func command(_ command: CMFCommand, payload: [UInt8] = []) -> Data {
        CMFFrame.request(command, sequence: sequence.next(), payload: payload).encoded()
    }

    private func choiceUpdate(_ setting: SettingID, _ raw: UInt8?) -> [DeviceUpdate] {
        raw.map { [.setting(setting, .choice(String($0)))] } ?? []
    }

    private func noiseUpdates(_ payload: [UInt8]) -> [DeviceUpdate] {
        for offset in stride(from: 0, to: payload.count - 1, by: 3) {
            guard payload[offset] == 1, let mode = CMFNoiseMode.decode(payload[offset + 1]) else { continue }
            return [.setting(CMFSetting.noiseMode, .choice(String(mode.rawValue)))]
        }
        return []
    }

    private func batteryUpdates(_ payload: [UInt8]) -> [DeviceUpdate] {
        var levels: [UInt8: BatteryLevel] = [:]
        for offset in stride(from: 0, to: payload.count - 1, by: 2) {
            let raw = payload[offset + 1]
            levels[payload[offset]] = BatteryLevel(percent: min(Int(raw & 0x7F), 100), isCharging: raw & 0x80 != 0)
        }
        if let stereo = levels[6] ?? levels[5] ?? levels[1] {
            return [.battery(Battery(percent: stereo.percent, isCharging: stereo.isCharging))]
        }
        return []
    }
}
