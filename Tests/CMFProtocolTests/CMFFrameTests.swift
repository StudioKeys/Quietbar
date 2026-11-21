import Foundation
import Testing

@testable import CMFProtocol

struct CMFFrameTests {
    @Test func requestEncodingMatchesElekidLayout() {
        let frame = CMFFrame.request(.getBattery, sequence: 1)

        #expect(frame.encoded().map { String(format: "%02x", $0) }.joined() == "55600607c0000001ad68")
    }

    @Test func payloadAndChecksumRoundTrip() {
        let original = CMFFrame.request(
            .setNoiseControl, sequence: 23, payload: [1, 4, 0])

        let decoded = try! CMFFrame.decode(original.encoded())

        #expect(decoded == original)
        #expect(decoded.payload == Data([1, 4, 0]))
        #expect(decoded.hasChecksum)
    }

    @Test func corruptChecksumIsRejected() {
        var encoded = CMFFrame.request(.getEQPreset, sequence: 8).encoded()
        encoded[encoded.count - 1] ^= 0x10

        do {
            _ = try CMFFrame.decode(encoded)
            Issue.record("corrupt frame decoded successfully")
        } catch CMFFrameError.invalidChecksum {
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }
}

struct CMFFramerTests {
    @Test func splitFrameIsReassembled() {
        var framer = CMFFramer()
        let frame = CMFFrame.request(.getBattery, sequence: 5).encoded()

        #expect(framer.push(Data(frame.prefix(6))).isEmpty)
        #expect(framer.push(Data(frame.dropFirst(6))) == [frame])
    }

    @Test func coalescedFramesAreSeparated() {
        var framer = CMFFramer()
        let first = CMFFrame.request(.getBattery, sequence: 1).encoded()
        let second = CMFFrame.request(.getEQPreset, sequence: 2).encoded()

        #expect(framer.push(first + second) == [first, second])
    }

    @Test func corruptFrameIsSkippedAndNextFrameRecovers() {
        var framer = CMFFramer()
        var corrupt = CMFFrame.request(.getBattery, sequence: 1).encoded()
        corrupt[corrupt.count - 1] ^= 0x20
        let valid = CMFFrame.request(.getEQPreset, sequence: 2).encoded()

        #expect(framer.push(corrupt + valid) == [valid])
    }

    @Test func strayStartByteWithBadChecksumKeepsFollowingFrame() {
        var framer = CMFFramer()
        // Claims a 1-byte payload with a checksum, so its candidate overlaps the real frame's first bytes.
        let stray = Data([0x55, 0x20, 0x00, 0x00, 0x00, 0x01, 0x00])
        let valid = CMFFrame.request(.getEQPreset, sequence: 2).encoded()

        #expect(framer.push(stray + valid) == [valid])
    }

    @Test func strayStartByteClaimingLongPayloadDoesNotStall() {
        var framer = CMFFramer()
        let valid = CMFFrame.request(.getBattery, sequence: 3).encoded()

        #expect(framer.push(Data([0x55]) + valid) == [valid])
    }
}
