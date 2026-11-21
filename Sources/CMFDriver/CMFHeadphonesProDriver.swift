import CMFProtocol
import Foundation
import HeadphoneKit

public struct CMFHeadphonesProDriver: DeviceDriver {
    public static let serviceUUID = UUID(uuidString: "AEAC4A03-DFF5-498F-843A-34487CF133EB")!

    public let model = DeviceModel(
        name: "CMF Headphone Pro",
        nameFragment: "CMF Headphone Pro",
        link: .rfcomm(serviceUUID: serviceUUID),
        settings: CMFSetting.descriptors,
        glyph: glyph,
        groupsToggles: true
    )

    public static let glyph = "cmf.headphonePro"

    private let sequence = CMFSequence()
    private let customEQ: CMFCustomEQCache

    public init(customEQ: CMFCustomEQCache = CMFCustomEQCache()) {
        self.customEQ = customEQ
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
        [
            command(.getNoiseControl, payload: [3]), command(.getSpatialAudio), command(.getEQPreset),
            command(.getCustomEQ), command(.getLowLag), command(.getDualConnection), command(.getBattery),
        ]
    }

    // Each write is followed by its query so the session confirms from the headphones' own answer.
    public func requests(for change: SettingChange, current: DeviceState) -> [Data]? {
        guard let (set, payload) = write(for: change, current: current),
            let query = confirmingRequest(for: change.id)
        else { return nil }
        return [command(set, payload: payload), query]
    }

    public func confirmingRequest(for setting: SettingID) -> Data? {
        switch setting {
        case CMFSetting.noiseMode, CMFSetting.ancLevel: command(.getNoiseControl, payload: [3])
        case CMFSetting.spatialMode: command(.getSpatialAudio)
        case CMFSetting.eqPreset: command(.getEQPreset)
        case CMFSetting.bass, CMFSetting.mid, CMFSetting.treble: command(.getCustomEQ)
        case CMFSetting.lowLag: command(.getLowLag)
        case CMFSetting.dualConnection: command(.getDualConnection)
        case .battery: command(.getBattery)
        default: nil
        }
    }

    public func updates(from packet: Data) -> [DeviceUpdate] {
        guard let frame = try? CMFFrame.decode(packet), frame.isResponseOK else { return [] }
        let payload = [UInt8](frame.payload)
        switch frame.command {
        case CMFCommand.getBattery.responseCommand, CMFCommand.batteryChanged.rawValue:
            return Self.battery(payload)
        case CMFCommand.getNoiseControl.responseCommand, CMFCommand.noiseControlChanged.rawValue:
            return Self.noise(payload)
        case CMFCommand.getSpatialAudio.responseCommand:
            return choice(CMFSetting.spatialMode, payload.first.flatMap(CMFSpatialMode.init)?.rawValue)
        case CMFCommand.getEQPreset.responseCommand:
            return choice(CMFSetting.eqPreset, payload.first.flatMap(CMFEQPreset.init)?.rawValue)
        case CMFCommand.getCustomEQ.responseCommand:
            return customEQUpdates(payload)
        case CMFCommand.getLowLag.responseCommand:
            return payload.first.map { [.setting(CMFSetting.lowLag, .bool($0 == 1))] } ?? []
        case CMFCommand.getDualConnection.responseCommand:
            return payload.first.map { [.setting(CMFSetting.dualConnection, .bool($0 != 0))] } ?? []
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

    private func write(for change: SettingChange, current: DeviceState) -> (CMFCommand, [UInt8])? {
        switch (change.id, change.value) {
        case (CMFSetting.noiseMode, .choice(let id)):
            return CMFNoiseMode(rawValue: id).map { (.setNoiseControl, [1, Self.noiseValue($0, current), 0]) }
        case (CMFSetting.ancLevel, .choice(let id)):
            return UInt8(id).flatMap(CMFANCLevel.init).map { (.setNoiseControl, [1, $0.rawValue, 0]) }
        case (CMFSetting.spatialMode, .choice(let id)):
            return UInt8(id).flatMap(CMFSpatialMode.init).map { (.setSpatialAudio, [$0.rawValue]) }
        case (CMFSetting.eqPreset, .choice(let id)):
            return UInt8(id).flatMap(CMFEQPreset.init).map { (.setEQPreset, [$0.rawValue]) }
        case (let id, .level(let gain)):
            guard let band = CMFSetting.band(for: id) else { return nil }
            // Cache the edit now so rapid changes to other bands build on it instead of the last read.
            return (.setCustomEQ, customEQ.edit(band, to: gain).encoded())
        case (CMFSetting.lowLag, .bool(let enabled)):
            return (.setLowLag, [enabled ? 1 : 2])
        case (CMFSetting.dualConnection, .bool(let enabled)):
            return (.setDualConnection, [enabled ? 1 : 0])
        default:
            return nil
        }
    }

    // Turning noise cancellation on restores the last level, matching the headphones' own behaviour.
    private static func noiseValue(_ mode: CMFNoiseMode, _ current: DeviceState) -> UInt8 {
        switch mode {
        case .anc:
            guard case .choice(let id) = current[CMFSetting.ancLevel], let level = UInt8(id) else {
                return CMFANCLevel.high.rawValue
            }
            return level
        case .transparency: return CMFNoiseValue.transparency
        case .off: return CMFNoiseValue.off
        }
    }

    private func command(_ command: CMFCommand, payload: [UInt8] = []) -> Data {
        CMFFrame.request(command, sequence: sequence.next(), payload: payload).encoded()
    }

    private func choice(_ setting: SettingID, _ raw: UInt8?) -> [DeviceUpdate] {
        raw.map { [.setting(setting, .choice(String($0)))] } ?? []
    }

    private func customEQUpdates(_ payload: [UInt8]) -> [DeviceUpdate] {
        guard let reported = CMFCustomEQ.decode(payload) else { return [] }
        let eq = customEQ.reconcile(reported)
        return [
            .setting(CMFSetting.bass, .level(eq.gain(.bass))),
            .setting(CMFSetting.mid, .level(eq.gain(.mid))),
            .setting(CMFSetting.treble, .level(eq.gain(.treble))),
        ]
    }

    // Records are (type, value, reserved): type 1 is the active mode, type 2 the last noise cancellation level.
    static func noise(_ payload: [UInt8]) -> [DeviceUpdate] {
        var updates: [DeviceUpdate] = []
        for offset in stride(from: 0, to: payload.count - 1, by: 3) {
            let value = payload[offset + 1]
            switch payload[offset] {
            case 1:
                if let level = CMFANCLevel(rawValue: value) {
                    updates.append(.setting(CMFSetting.noiseMode, .choice(CMFNoiseMode.anc.id)))
                    updates.append(.setting(CMFSetting.ancLevel, .choice(String(level.rawValue))))
                } else if value == CMFNoiseValue.off {
                    updates.append(.setting(CMFSetting.noiseMode, .choice(CMFNoiseMode.off.id)))
                } else if value == CMFNoiseValue.transparency || value == CMFNoiseValue.transparencyAlias {
                    updates.append(.setting(CMFSetting.noiseMode, .choice(CMFNoiseMode.transparency.id)))
                }
            case 2:
                if let level = CMFANCLevel(rawValue: value) {
                    updates.append(.setting(CMFSetting.ancLevel, .choice(String(level.rawValue))))
                }
            default:
                continue
            }
        }
        return updates
    }

    // Payload is a pair count followed by (component, level) pairs; bit 7 of the level means charging.
    static func battery(_ payload: [UInt8]) -> [DeviceUpdate] {
        guard let count = payload.first else { return [] }
        var levels: [UInt8: BatteryLevel] = [:]
        for index in 0..<Int(count) {
            let offset = 1 + index * 2
            guard offset + 1 < payload.count else { break }
            let raw = payload[offset + 1]
            levels[payload[offset]] = BatteryLevel(percent: min(Int(raw & 0x7F), 100), isCharging: raw & 0x80 != 0)
        }
        guard let level = levels[6] ?? levels[5] ?? levels[1] else { return [] }
        return [.battery(Battery(percent: level.percent, isCharging: level.isCharging))]
    }
}
