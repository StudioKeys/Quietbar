import Foundation
import HeadphoneKit

public struct CMFFramer: PacketFramer {
    public static let maximumPayloadLength = 4096

    private var buffer = Data()

    public init() {}

    public mutating func push(_ chunk: Data) -> [Data] {
        buffer.append(chunk)
        var frames: [Data] = []

        while buffer.count >= 8 {
            guard let start = buffer.firstIndex(of: CMFFrame.startOfFrame) else {
                buffer.removeAll()
                break
            }
            if start != buffer.startIndex {
                buffer = Data(buffer[start...])
            }

            let bytes = [UInt8](buffer)
            let payloadLength = Int(UInt16(bytes[5]) | UInt16(bytes[6]) << 8)
            let control = UInt16(bytes[1]) | UInt16(bytes[2]) << 8
            let checksumLength = control & 0x20 == 0 ? 0 : 2
            guard payloadLength <= Self.maximumPayloadLength else {
                buffer.removeFirst()
                continue
            }

            let totalLength = 8 + payloadLength + checksumLength
            guard buffer.count >= totalLength else { break }
            let candidate = Data(buffer.prefix(totalLength))
            buffer.removeFirst(totalLength)
            if (try? CMFFrame.decode(candidate)) != nil {
                frames.append(candidate)
            }
        }
        return frames
    }
}
