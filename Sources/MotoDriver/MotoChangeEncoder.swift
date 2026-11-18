import Foundation
import HeadphoneKit
import MotoProtocol

enum MotoChangeEncoder {
    static func requests(for change: SettingChange) -> [Data]? {
        guard let (opcode, payload) = command(for: change) else { return nil }
        return [MotoFrame.encode(.command(opcode, payload: payload))]
    }

    private static func command(for change: SettingChange) -> (MotoOpcode, [UInt8])? {
        switch (change.id, change.value) {
        case (MotoSetting.noiseMode, .choice(let id)):
            NoiseControl(rawValue: id).map { (.setNoiseControl, $0.payload) }
        case (MotoSetting.eqPreset, .choice(let id)):
            UInt8(id).flatMap(EqPreset.init(rawValue:)).map { (.setEQSet, [$0.rawValue]) }
        case (MotoSetting.spatialSound, .bool(let isOn)): (.setSpatialAudio, [byte(isOn), 0x00])
        case (MotoSetting.hiRes, .bool(let isOn)): (.setHiRes, [byte(isOn)])
        case (MotoSetting.volumeBoost, .bool(let isOn)): (.setVolumeBoost, [byte(isOn)])
        case (MotoSetting.gameMode, .bool(let isOn)): (.setGameMode, [byte(isOn)])
        case (MotoSetting.inEarDetection, .bool(let isOn)): (.setInEarDetection, [byte(isOn)])
        case (MotoSetting.dualConnection, .bool(let isOn)): (.setDualConnection, [0x01, byte(isOn)])
        default: nil
        }
    }

    private static func byte(_ isOn: Bool) -> UInt8 { isOn ? 1 : 0 }
}
