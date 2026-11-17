import Foundation

public enum FrameError: Error, Equatable, Sendable {
    case tooShort
    case badHeader(UInt8)
    case lengthMismatch(declared: Int, actual: Int)
}

public struct Frame: Sendable, Equatable {
    static let header: UInt8 = 0xAA
    static let wideLengthReplies: Set<UInt8> = [0xA2]

    public let command: UInt8
    public let payload: [UInt8]
    let usesWideLength: Bool

    init(command: UInt8, payload: [UInt8], usesWideLength: Bool = false) {
        self.command = command
        self.payload = payload
        self.usesWideLength = usesWideLength
    }

    public func encoded() -> Data {
        Data([Self.header, command] + lengthBytes + payload)
    }

    public static func decode(_ data: Data) throws(FrameError) -> Frame {
        let bytes = [UInt8](data)
        guard bytes.count >= 3 else { throw .tooShort }
        guard bytes[0] == header else { throw .badHeader(bytes[0]) }
        let command = bytes[1]
        let usesWideLength = wideLengthReplies.contains(command)
        let lengthWidth = usesWideLength ? 2 : 1
        let bodyStart = 2 + lengthWidth
        guard bytes.count >= bodyStart else { throw .tooShort }
        let declared = declaredLength(bytes[2..<bodyStart])
        let payload = Array(bytes[bodyStart...])
        guard payload.count == declared else {
            throw .lengthMismatch(declared: declared, actual: payload.count)
        }
        return Frame(command: command, payload: payload, usesWideLength: usesWideLength)
    }

    private var lengthBytes: [UInt8] {
        let low = UInt8(truncatingIfNeeded: payload.count)
        guard usesWideLength else { return [low] }
        return [low, UInt8(truncatingIfNeeded: payload.count >> 8)]
    }

    private static func declaredLength(_ bytes: ArraySlice<UInt8>) -> Int {
        bytes.reversed().reduce(0) { ($0 << 8) | Int($1) }
    }
}
