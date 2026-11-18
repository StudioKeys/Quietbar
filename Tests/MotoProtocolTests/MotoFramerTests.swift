import Foundation
import Testing

@testable import MotoProtocol

struct MotoFramerTests {
    @Test func splitFrameIsReassembled() {
        var framer = MotoFramer()
        let frame = MotoFrameTests.batteryNotification

        let first = framer.push(frame.prefix(7))
        let second = framer.push(frame.dropFirst(7))

        #expect(first.isEmpty)
        #expect(second == [frame])
    }

    @Test func twoFramesInOneChunk() {
        var framer = MotoFramer()

        let frames = framer.push(MotoFrameTests.versionReply + MotoFrameTests.inCaseNotification)

        #expect(frames == [MotoFrameTests.versionReply, MotoFrameTests.inCaseNotification])
    }

    @Test func garbageBeforeHeadIsSkipped() {
        var framer = MotoFramer()

        let frames = framer.push(Data([0x00, 0x48, 0x45]) + MotoFrameTests.versionReply)

        #expect(frames == [MotoFrameTests.versionReply])
    }

    @Test func frameWithBadTailIsDroppedAndFramerRecovers() {
        var framer = MotoFramer()
        var broken = MotoFrameTests.inCaseNotification
        broken[broken.count - 1] = 0x00

        let frames = framer.push(broken + MotoFrameTests.versionReply)

        #expect(frames == [MotoFrameTests.versionReply])
    }
}
