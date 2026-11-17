import Foundation
import Testing

@testable import JBLProtocol

struct FrameTests {
    @Test func encodesShortFrame() {
        let frame = Frame(command: 0x91, payload: [0x11])

        #expect(frame.encoded() == Data(hex: "aa 91 01 11"))
    }

    @Test func encodesEqFrameWithSixteenBitLength() {
        let frame = Frame(command: 0xA2, payload: [UInt8](repeating: 0, count: 116), usesWideLength: true)

        let encoded = frame.encoded()

        #expect(encoded.prefix(4) == Data(hex: "aa a2 74 00"))
        #expect(encoded.count == 120)
    }

    @Test func decodesNoiseReply() throws {
        let frame = try Frame.decode(Data(hex: "aa 91 07 12 01 01 02 00 03 00"))

        #expect(frame.command == 0x91)
        #expect(frame.payload == [0x12, 1, 1, 2, 0, 3, 0])
    }

    @Test func decodesEqReplyWithSixteenBitLength() throws {
        let data = Data(hex: "aa a2 74 00") + Data(repeating: 0x0A, count: 116)

        let frame = try Frame.decode(data)

        #expect(frame.payload.count == 116)
    }

    @Test func decodeRejectsTruncatedFrame() {
        #expect(throws: FrameError.lengthMismatch(declared: 7, actual: 2)) {
            try Frame.decode(Data(hex: "aa 91 07 12 01"))
        }
    }

    @Test func decodeRejectsTrailingBytes() {
        #expect(throws: FrameError.lengthMismatch(declared: 1, actual: 2)) {
            try Frame.decode(Data(hex: "aa 91 01 11 00"))
        }
    }

    @Test func decodeRejectsBadHeader() {
        #expect(throws: FrameError.badHeader(0xAB)) {
            try Frame.decode(Data(hex: "ab 91 01 11"))
        }
    }

    @Test func decodeRejectsTooShort() {
        #expect(throws: FrameError.tooShort) {
            try Frame.decode(Data(hex: "aa 91"))
        }
    }
}
