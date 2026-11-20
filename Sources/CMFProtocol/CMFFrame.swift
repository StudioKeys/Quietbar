import Foundation

public enum CMFFrameError: Error, Equatable, Sendable {
    case tooShort
    case invalidStart(UInt8)
    case lengthMismatch(expected: Int, actual: Int)
    case invalidChecksum(expected: UInt16, actual: UInt16)
}

public struct CMFFrame: Hashable, Sendable {
    public static let startOfFrame: UInt8 = 0x55
    public static let deviceType: UInt16 = 6

    public let control: UInt16
    public let command: UInt16
    public let sequence: UInt8
    public let payload: Data

    public init(control: UInt16, command: UInt16, sequence: UInt8, payload: Data = Data()) {
        self.control = control
        self.command = command
        self.sequence = sequence
        self.payload = payload
    }

    public var isResponseOK: Bool {
        control & 0x1F == 0
    }

    public var hasChecksum: Bool {
        control & 0x20 != 0
    }

    public static func request(
        _ command: CMFCommand,
        sequence: UInt8,
        payload: [UInt8] = []
    ) -> CMFFrame {
        CMFFrame(
            control: (deviceType << 8) | 0x60,
            command: command.rawValue,
            sequence: sequence,
            payload: Data(payload)
        )
    }

    public func encoded() -> Data {
        var bytes = Data([Self.startOfFrame])
        bytes.append(contentsOf: control.littleEndianBytes)
        bytes.append(contentsOf: command.littleEndianBytes)
        bytes.append(contentsOf: UInt16(payload.count).littleEndianBytes)
        bytes.append(sequence)
        bytes.append(payload)
        if hasChecksum {
            bytes.append(contentsOf: CMFCRC16.checksum(bytes).littleEndianBytes)
        }
        return bytes
    }

    public static func decode(_ data: Data) throws(CMFFrameError) -> CMFFrame {
        let bytes = [UInt8](data)
        guard bytes.count >= 8 else { throw .tooShort }
        guard bytes[0] == startOfFrame else { throw .invalidStart(bytes[0]) }

        let control = UInt16(littleEndian: bytes[1], bytes[2])
        let command = UInt16(littleEndian: bytes[3], bytes[4])
        let length = Int(UInt16(littleEndian: bytes[5], bytes[6]))
        let checksumLength = control & 0x20 == 0 ? 0 : 2
        let expectedLength = 8 + length + checksumLength
        guard bytes.count == expectedLength else {
            throw .lengthMismatch(expected: expectedLength, actual: bytes.count)
        }

        let payload = Data(bytes[8..<(8 + length)])
        let frame = CMFFrame(control: control, command: command, sequence: bytes[7], payload: payload)
        if frame.hasChecksum {
            let offset = 8 + length
            let expected = CMFCRC16.checksum(Data(bytes[..<offset]))
            let actual = UInt16(littleEndian: bytes[offset], bytes[offset + 1])
            guard actual == expected else { throw .invalidChecksum(expected: expected, actual: actual) }
        }
        return frame
    }
}

extension FixedWidthInteger {
    fileprivate var littleEndianBytes: [UInt8] {
        (0..<(bitWidth / 8)).map { UInt8(truncatingIfNeeded: self >> ($0 * 8)) }
    }
}

extension UInt16 {
    fileprivate init(littleEndian low: UInt8, _ high: UInt8) {
        self = UInt16(low) | UInt16(high) << 8
    }
}
