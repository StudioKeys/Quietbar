import Foundation
import HeadphoneKit
import JBLProtocol

public struct JBLLive770NCDriver: DeviceDriver {
    public let model = DeviceModel(
        name: "JBL Live 770NC",
        nameFragment: "770NC",
        link: .gatt(Self.gatt),
        settings: JBLSetting.descriptors
    )

    private static let refreshCommands: [Command] = Command.refreshAll + [.querySmartAudioVideo, .queryDeviceStatus]

    public static let gatt = GattProfile(
        service: "65786365-6c70-6f69-6e74-2e636f6d0000",
        notify: "65786365-6c70-6f69-6e74-2e636f6d0001",
        write: "65786365-6c70-6f69-6e74-2e636f6d0002"
    )

    public init() {}

    public var refreshRequests: [Data] {
        Self.refreshCommands.map { $0.frame.encoded() }
    }

    public func requests(for change: SettingChange, current: DeviceState) -> [Data]? {
        JBLChangeEncoder.command(for: change, current: current).map { [$0.frame.encoded()] }
    }

    public func confirmingRequest(for setting: SettingID) -> Data? {
        Self.query(for: setting)?.frame.encoded()
    }

    public func updates(from packet: Data) -> [DeviceUpdate] {
        guard let frame = try? Frame.decode(packet) else { return [] }
        return JBLUpdateDecoder.updates(from: frame)
    }

    private static func query(for setting: SettingID) -> Command? {
        switch setting {
        case JBLSetting.noiseMode: .queryNoiseMode
        case JBLSetting.adaptiveAnc, JBLSetting.leakageCompensation, JBLSetting.ambientLevel: .queryAdvancedAnc
        case JBLSetting.eqPreset: .queryEq
        case JBLSetting.spatialSound, JBLSetting.spatialMode: .querySpatial
        case JBLSetting.lowVolumeEq: .queryLowVolumeEq
        case JBLSetting.balance: .queryBalance
        case JBLSetting.smartAudioVideo, JBLSetting.smartAudioVideoMode: .querySmartAudioVideo
        case JBLSetting.autoPlayPause: .queryDeviceStatus
        case .battery: .queryBattery
        default: nil
        }
    }
}
