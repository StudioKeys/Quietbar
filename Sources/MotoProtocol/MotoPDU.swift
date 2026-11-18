import Foundation

public struct MotoPDU: Hashable, Sendable {
    public static let commandType: UInt8 = 0x80
    public static let headerLength = 8

    public let opcode: UInt16
    public let type: UInt8
    public let result: UInt8
    public let seq: UInt16
    public let payload: Data

    public init(opcode: UInt16, type: UInt8, result: UInt8, seq: UInt16, payload: Data) {
        self.opcode = opcode
        self.type = type
        self.result = result
        self.seq = seq
        self.payload = payload
    }

    public static func command(_ opcode: MotoOpcode, payload: [UInt8] = []) -> MotoPDU {
        MotoPDU(opcode: opcode.rawValue, type: commandType, result: 0, seq: 0, payload: Data(payload))
    }

    var bytes: Data {
        var data = Data([UInt8(opcode >> 8), UInt8(opcode & 0xFF), type, result])
        data.append(contentsOf: UInt16(payload.count).littleEndianBytes)
        data.append(contentsOf: seq.littleEndianBytes)
        data.append(payload)
        return data
    }

    init?(bytes: Data) {
        let raw = [UInt8](bytes)
        guard raw.count >= Self.headerLength else { return nil }
        let length = Int(UInt16(raw[4]) | UInt16(raw[5]) << 8)
        guard raw.count == Self.headerLength + length else { return nil }
        self.init(
            opcode: UInt16(raw[0]) << 8 | UInt16(raw[1]),
            type: raw[2],
            result: raw[3],
            seq: UInt16(raw[6]) | UInt16(raw[7]) << 8,
            payload: Data(raw[Self.headerLength...])
        )
    }
}

extension FixedWidthInteger {
    var littleEndianBytes: [UInt8] {
        (0..<(Self.bitWidth / 8)).map { UInt8(truncatingIfNeeded: self >> ($0 * 8)) }
    }
}
