enum ReplyDecoder {
    private static let modeStatus: UInt8 = 0x12
    private static let advancedAncStatus: UInt8 = 0x22
    private static let ambientLevelKey: UInt8 = 0xA1
    private static let status: UInt8 = 0x02
    private static let batteryStatus: UInt8 = 0x01
    private static let eqStatus: UInt8 = 0x04

    static func decode(_ frame: Frame) -> Reply? {
        let payload = frame.payload
        switch (frame.command, payload.first) {
        case (Opcode.noise, modeStatus): return noiseMode(payload).map(Reply.noiseMode)
        case (Opcode.noise, advancedAncStatus): return ambientLevel(payload).map(Reply.ambientLevel)
        case (Opcode.battery, batteryStatus): return battery(payload).map(Reply.battery)
        case (Opcode.spatial, status): return spatial(payload).map(Reply.spatial)
        case (Opcode.lowVolumeEq, status): return lowVolumeEq(payload).map(Reply.lowVolumeEq)
        case (Opcode.eq, eqStatus): return eq(payload).map(Reply.eq)
        case (Opcode.balance, status): return balance(payload).map(Reply.balance)
        default: return nil
        }
    }

    private static func noiseMode(_ payload: [UInt8]) -> NoiseMode? {
        guard payload.count == 7 else { return nil }
        let flags = [payload[2], payload[4], payload[6]]
        switch flags {
        case [1, 0, 0]: return .anc
        case [0, 1, 0]: return .ambientAware
        case [0, 0, 1]: return .talkThru
        case [0, 0, 0]: return .off
        default: return nil
        }
    }

    private static func ambientLevel(_ payload: [UInt8]) -> AmbientLevel? {
        let pairs = stride(from: 1, to: payload.count - 1, by: 2).map { (payload[$0], payload[$0 + 1]) }
        guard let level = pairs.first(where: { $0.0 == ambientLevelKey })?.1 else { return nil }
        return AmbientLevel(Int(level))
    }

    private static func battery(_ payload: [UInt8]) -> Battery? {
        guard payload.count >= 4 else { return nil }
        return Battery(percent: Int(payload[3]), isCharging: payload[1] != 0)
    }

    private static func spatial(_ payload: [UInt8]) -> SpatialSetting? {
        guard payload.count == 3, let mode = SpatialMode(rawValue: payload[2]) else { return nil }
        return SpatialSetting(isOn: payload[1] != 0, mode: mode)
    }

    private static func lowVolumeEq(_ payload: [UInt8]) -> Bool? {
        guard payload.count == 2 else { return nil }
        return payload[1] != 0
    }

    private static func eq(_ payload: [UInt8]) -> EqSelection? {
        guard payload.count >= 2 else { return nil }
        guard let preset = EqPreset(id: payload[1]) else { return .custom(payload[1]) }
        return .preset(preset)
    }

    private static func balance(_ payload: [UInt8]) -> Balance? {
        guard payload.count == 5 else { return nil }
        guard payload[2] != 0 else { return Balance(offset: 0) }
        return Balance(wire: payload[4])
    }
}
