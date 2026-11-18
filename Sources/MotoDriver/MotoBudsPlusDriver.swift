import Foundation
import HeadphoneKit
import MotoProtocol

public struct MotoBudsPlusDriver: DeviceDriver {
    public static let serviceUUID = "fc9d9fe0-4899-11ee-be56-0242ac120002"
    private static let supportInfoRequest: [UInt8] = [0xFC, 0xFF, 0x05, 0x00]

    public let model = DeviceModel(
        name: "moto buds+",
        nameFragment: "moto buds",
        link: .rfcomm(serviceUUID: serviceUUID),
        settings: MotoSetting.descriptors
    )

    private static let queries: [SettingID: MotoOpcode] = [
        MotoSetting.noiseMode: .noiseControl,
        MotoSetting.eqPreset: .eqSet,
        MotoSetting.spatialSound: .spatialAudio,
        MotoSetting.hiRes: .hiRes,
        MotoSetting.volumeBoost: .volumeBoost,
        MotoSetting.gameMode: .gameMode,
        MotoSetting.inEarDetection: .inEarDetection,
        MotoSetting.dualConnection: .dualConnection,
        .battery: .batteryLevel,
    ]

    public init() {}

    public var handshakeRequests: [Data] {
        [
            command(.profileVersion), command(.supportFeatures),
            command(.listSupportInfo, Self.supportInfoRequest),
        ]
    }

    public var refreshRequests: [Data] {
        (model.settings.map(\.id) + [.battery]).compactMap(confirmingRequest)
    }

    public func requests(for change: SettingChange, current: DeviceState) -> [Data]? {
        MotoChangeEncoder.requests(for: change)
    }

    public func confirmingRequest(for setting: SettingID) -> Data? {
        Self.queries[setting].map { command($0) }
    }

    public func updates(from packet: Data) -> [DeviceUpdate] {
        MotoUpdateDecoder.updates(from: packet)
    }

    public func makeFramer() -> any PacketFramer {
        MotoFramer()
    }

    public func isReady(_ state: DeviceState) -> Bool {
        state[MotoSetting.noiseMode] != nil && state[MotoSetting.eqPreset] != nil
    }

    private func command(_ opcode: MotoOpcode, _ payload: [UInt8] = []) -> Data {
        MotoFrame.encode(.command(opcode, payload: payload))
    }
}
