import Foundation
import HeadphoneKit

public struct MotoFramer: PacketFramer {
    private var buffer = Data()

    public init() {}

    public mutating func push(_ chunk: Data) -> [Data] {
        buffer.append(chunk)
        var frames: [Data] = []
        while let frame = nextFrame() {
            frames.append(frame)
        }
        return frames
    }

    private mutating func nextFrame() -> Data? {
        while true {
            guard let start = buffer.firstRange(of: MotoFrame.head)?.lowerBound else {
                buffer = Data(buffer.suffix(MotoFrame.head.count - 1))
                return nil
            }
            buffer = Data(buffer[start...])
            guard let length = MotoFrame.bodyLength(in: buffer) else { return nil }
            let total = MotoFrame.overhead + length
            guard buffer.count >= total else { return nil }
            let frame = Data(buffer.prefix(total))
            if frame.suffix(MotoFrame.tail.count) == MotoFrame.tail {
                buffer = Data(buffer.dropFirst(total))
                return frame
            }
            buffer = Data(buffer.dropFirst())
        }
    }
}
