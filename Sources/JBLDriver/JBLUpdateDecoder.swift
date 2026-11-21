import HeadphoneKit
import JBLProtocol

enum JBLUpdateDecoder {
    private static let advancedAncStatus: UInt8 = 0x22
    private static let smartAudioVideoStatus: UInt8 = 0x83
    private static let deviceStatusReply: UInt8 = 0x22
    private static let allStatusType: UInt8 = 0x30
    private static let autoPlayPauseIndex = 8

    static func updates(from frame: Frame) -> [DeviceUpdate] {
        switch (frame.command, frame.payload.first) {
        case (0x91, advancedAncStatus): advancedAnc(frame.payload)
        case (smartAudioVideoStatus, _): smartAudioVideo(frame.payload)
        case (deviceStatusReply, allStatusType): autoPlayPause(frame.payload)
        default: updates(from: Reply(frame: frame))
        }
    }

    private static func updates(from reply: Reply) -> [DeviceUpdate] {
        switch reply {
        case .noiseMode(let mode): [.setting(JBLSetting.noiseMode, .choice(mode.id))]
        case .ambientLevel(let level): [.setting(JBLSetting.ambientLevel, .level(Int(level.value)))]
        case .battery(let battery): [.battery(Battery(percent: battery.percent, isCharging: battery.isCharging))]
        case .spatial(let spatial):
            [
                .setting(
                    JBLSetting.spatialSound, .choice(spatial.isOn ? spatial.mode.settingID : JBLSetting.spatialOff.id)),
                .setting(JBLSetting.spatialMode, .choice(spatial.mode.settingID)),
            ]
        case .lowVolumeEq(let isOn): [.setting(JBLSetting.lowVolumeEq, .bool(isOn))]
        case .eq(.preset(let preset)): [.setting(JBLSetting.eqPreset, .choice(preset.settingID))]
        case .eq(.custom): [.setting(JBLSetting.eqPreset, .choice(JBLSetting.customEq))]
        case .balance(let balance): [.setting(JBLSetting.balance, .level(balance.offset))]
        case .unknown: []
        }
    }

    private static func advancedAnc(_ payload: [UInt8]) -> [DeviceUpdate] {
        let pairs = stride(from: 1, to: payload.count - 1, by: 2).map { (payload[$0], payload[$0 + 1]) }
        return pairs.compactMap { key, value in
            switch key {
            case 0x01: .setting(JBLSetting.adaptiveAnc, .bool(value != 0))
            case 0x05: .setting(JBLSetting.leakageCompensation, .bool(value != 0))
            case 0xA1: AmbientLevel(Int(value)).map { .setting(JBLSetting.ambientLevel, .level(Int($0.value))) }
            default: nil
            }
        }
    }

    private static func smartAudioVideo(_ payload: [UInt8]) -> [DeviceUpdate] {
        guard let preset = SmartAudioVideoPreset(payload: payload) else { return [] }
        return [.setting(JBLSetting.smartAudioVideo, .choice(SmartMode(preset: preset).rawValue))]
    }

    private static func autoPlayPause(_ payload: [UInt8]) -> [DeviceUpdate] {
        guard payload.count > autoPlayPauseIndex else { return [] }
        return [.setting(JBLSetting.autoPlayPause, .bool(payload[autoPlayPauseIndex] != 0))]
    }
}
