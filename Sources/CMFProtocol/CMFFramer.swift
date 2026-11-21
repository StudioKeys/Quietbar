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

            guard let totalLength = Self.frameLength(in: buffer, at: buffer.startIndex) else {
                buffer.removeFirst()
                continue
            }
            guard buffer.count >= totalLength else {
                // A stray start byte can claim a long payload and stall the stream; resume at a later complete frame.
                guard let next = Self.completeFrameStart(in: buffer) else { break }
                buffer = Data(buffer[next...])
                continue
            }
            let candidate = Data(buffer.prefix(totalLength))
            guard (try? CMFFrame.decode(candidate)) != nil else {
                // A stray start byte can look like a header; skip only it so the real frame behind it survives.
                buffer.removeFirst()
                continue
            }
            buffer.removeFirst(totalLength)
            frames.append(candidate)
        }
        return frames
    }

    private static func frameLength(in buffer: Data, at start: Data.Index) -> Int? {
        guard buffer.endIndex - start >= 8 else { return nil }
        let control = UInt16(buffer[start + 1]) | UInt16(buffer[start + 2]) << 8
        let payloadLength = Int(UInt16(buffer[start + 5]) | UInt16(buffer[start + 6]) << 8)
        guard payloadLength <= maximumPayloadLength else { return nil }
        return 8 + payloadLength + (control & 0x20 == 0 ? 0 : 2)
    }

    private static func completeFrameStart(in buffer: Data) -> Data.Index? {
        var index = buffer.index(after: buffer.startIndex)
        while let start = buffer[index...].firstIndex(of: CMFFrame.startOfFrame) {
            if let length = frameLength(in: buffer, at: start), buffer.endIndex - start >= length,
                (try? CMFFrame.decode(Data(buffer[start..<(start + length)]))) != nil
            {
                return start
            }
            index = buffer.index(after: start)
        }
        return nil
    }
}
