import Foundation
import HeadphoneKit
import MotoProtocol

enum MotoUpdateDecoder {
    private static let unknownLevel: UInt8 = 0xFF
    private static let chargingBit: UInt8 = 0x80
    private static let maxPercent = 100

    static func updates(from frame: Data) -> [DeviceUpdate] {
        guard let pdu = MotoFrame.decode(frame), let opcode = MotoOpcode(rawValue: pdu.opcode) else { return [] }
        let payload = [UInt8](pdu.payload)
        guard !payload.isEmpty else { return [] }
        return updates(for: opcode, payload: payload)
    }

    private static func updates(for opcode: MotoOpcode, payload: [UInt8]) -> [DeviceUpdate] {
        switch opcode {
        case .noiseControl, .noiseControlChanged:
            NoiseControl(payload: payload).map { [.setting(MotoSetting.noiseMode, .choice($0.rawValue))] } ?? []
        case .eqSet, .eqSetChanged:
            EqPreset(rawValue: payload[0]).map { [.setting(MotoSetting.eqPreset, .choice($0.option.id))] } ?? []
        case .spatialAudio, .spatialAudioChanged: [.setting(MotoSetting.spatialSound, .bool(payload[0] == 1))]
        case .hiRes, .hiResChanged: switchUpdate(MotoSetting.hiRes, payload.last)
        case .gameMode, .gameModeChanged: switchUpdate(MotoSetting.gameMode, payload.first)
        case .volumeBoost, .volumeBoostChanged: switchUpdate(MotoSetting.volumeBoost, payload.first)
        case .inEarDetection, .inEarDetectionChanged: switchUpdate(MotoSetting.inEarDetection, payload.first)
        case .dualConnection, .dualConnectionChanged: switchUpdate(MotoSetting.dualConnection, payload.last)
        case .batteryLevel, .batteryChanged: battery(payload).map { [.battery($0)] } ?? []
        default: []
        }
    }

    private static func switchUpdate(_ id: SettingID, _ byte: UInt8?) -> [DeviceUpdate] {
        byte.map { [.setting(id, .bool($0 == 1))] } ?? []
    }

    private static func battery(_ payload: [UInt8]) -> Battery? {
        guard payload.count >= 3 else { return nil }
        return Battery.buds(left: level(payload[0]), right: level(payload[1]), caseLevel: level(payload[2]))
    }

    private static func level(_ byte: UInt8) -> BatteryLevel? {
        guard byte != unknownLevel else { return nil }
        let percent = min(Int(byte & ~chargingBit), maxPercent)
        return BatteryLevel(percent: percent, isCharging: byte & chargingBit != 0)
    }
}
