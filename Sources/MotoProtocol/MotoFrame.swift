import Foundation

public enum MotoFrame {
    static let head = Data("HEAD".utf8)
    static let tail = Data("TAIL".utf8)
    static let lengthFieldSize = 2
    static let checksumSize = 4
    static let overhead = head.count + lengthFieldSize + checksumSize + tail.count
    static let maxBodyLength = 1024

    public static func encode(_ pdu: MotoPDU) -> Data {
        let body = pdu.bytes
        var frame = head
        frame.append(contentsOf: UInt16(body.count).littleEndianBytes)
        frame.append(body)
        frame.append(contentsOf: CRC32.checksum(frame).littleEndianBytes)
        frame.append(tail)
        return frame
    }

    public static func decode(_ frame: Data) -> MotoPDU? {
        let raw = Data(frame)
        guard raw.count >= overhead, raw.prefix(head.count) == head, raw.suffix(tail.count) == tail,
            let length = bodyLength(in: raw), raw.count == overhead + length
        else { return nil }
        let bodyStart = head.count + lengthFieldSize
        return MotoPDU(bytes: raw.subdata(in: bodyStart..<(bodyStart + length)))
    }

    static func bodyLength(in frame: Data) -> Int? {
        let raw = [UInt8](frame.prefix(head.count + lengthFieldSize))
        guard raw.count == head.count + lengthFieldSize else { return nil }
        return Int(UInt16(raw[4]) | UInt16(raw[5]) << 8)
    }
}
