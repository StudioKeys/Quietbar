import Foundation
import Testing

@testable import MotoProtocol

extension Data {
    init(hex: String) {
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            bytes.append(UInt8(hex[index..<next], radix: 16)!)
            index = next
        }
        self.init(bytes)
    }
}

struct MotoFrameTests {
    static let batteryNotification = Data(hex: "484541440b0000094000030000004d47ff000000005441494c")
    static let versionReply = Data(hex: "484541440a0000002000020000000202000000005441494c")
    static let inCaseNotification = Data(hex: "484541440a00040c4000020000000000000000005441494c")

    @Test func encodesProfileVersionQuery() {
        #expect(
            MotoFrame.encode(.command(.profileVersion))
                == Data(hex: "48454144080000008000000000006677c9c35441494c"))
    }

    @Test func encodesNoiseCancellingCommand() {
        #expect(
            MotoFrame.encode(.command(.setNoiseControl, payload: [0x01, 0x03]))
                == Data(hex: "484541440a00020180000200000001039962708e5441494c"))
    }

    @Test func decodesBatteryNotification() {
        let pdu = MotoFrame.decode(Self.batteryNotification)

        #expect(pdu?.opcode == MotoOpcode.batteryChanged.rawValue)
        #expect(pdu?.type == 0x40)
        #expect(pdu?.payload == Data([0x4d, 0x47, 0xff]))
    }

    @Test func decodesVersionReply() {
        let pdu = MotoFrame.decode(Self.versionReply)

        #expect(pdu?.opcode == 0)
        #expect(pdu?.type == 0x20)
        #expect(pdu?.payload == Data([0x02, 0x02]))
    }

    @Test func rejectsFrameWithoutTail() {
        var broken = Self.versionReply
        broken[broken.count - 1] = 0x00

        #expect(MotoFrame.decode(broken) == nil)
    }

    @Test func noCommandUsesForbiddenOpcode() {
        let forbidden: Set<UInt16> = Set(1280...1283).union([1029, 1536, 1537]).union(1792...1794).union(2560...2562)

        #expect(MotoOpcode.allCases.allSatisfy { !forbidden.contains($0.rawValue) })
    }
}
