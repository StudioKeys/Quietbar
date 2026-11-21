import HeadphoneKit
import JBLProtocol

enum JBLChangeEncoder {
    static func command(for change: SettingChange, current: DeviceState) -> Command? {
        switch (change.id, change.value) {
        case (JBLSetting.noiseMode, .choice(let id)): NoiseMode(id: id).map(Command.setNoiseMode)
        case (JBLSetting.adaptiveAnc, .bool(let isOn)): .setAdaptiveAnc(isOn)
        case (JBLSetting.leakageCompensation, .bool(let isOn)): .setLeakageCompensation(isOn)
        case (JBLSetting.ambientLevel, .level(let level)): AmbientLevel(level).map(Command.setAmbientLevel)
        case (JBLSetting.eqPreset, .choice(let id)): EqPreset(settingID: id).map(Command.setEqPreset)
        case (JBLSetting.spatialSound, .choice(let id)): spatial(id, current: current)
        case (JBLSetting.lowVolumeEq, .bool(let isOn)): .setLowVolumeEq(isOn)
        case (JBLSetting.balance, .level(let offset)): Balance(offset: offset).map(Command.setBalance)
        case (JBLSetting.smartAudioVideo, .choice(let id)):
            SmartMode(rawValue: id).map { .setSmartAudioVideo($0.preset) }
        case (JBLSetting.autoPlayPause, .bool(let isOn)): .setAutoPlayPause(isOn)
        default: nil
        }
    }

    private static func currentSpatialMode(in state: DeviceState) -> SpatialMode {
        guard case .choice(let id) = state[JBLSetting.lastSpatialMode], let mode = SpatialMode(settingID: id) else {
            return .music
        }
        return mode
    }

    private static func spatial(_ id: String, current: DeviceState) -> Command? {
        if id == JBLSetting.spatialOff.id {
            return .setSpatial(SpatialSetting(isOn: false, mode: currentSpatialMode(in: current)))
        }
        return SpatialMode(settingID: id).map { .setSpatial(SpatialSetting(isOn: true, mode: $0)) }
    }
}
