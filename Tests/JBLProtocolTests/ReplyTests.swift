import Foundation
import Testing

@testable import JBLProtocol

struct ReplyTests {
    static let decodings: [(String, Reply)] = [
        ("aa 91 07 12 01 01 02 00 03 00", .noiseMode(.anc)),
        ("aa 91 07 12 01 00 02 01 03 00", .noiseMode(.ambientAware)),
        ("aa 91 07 12 01 00 02 00 03 01", .noiseMode(.talkThru)),
        ("aa 91 07 12 01 00 02 00 03 00", .noiseMode(.off)),
        ("aa 91 09 22 01 01 04 04 05 01 a1 07", .ambientLevel(AmbientLevel(7)!)),
        ("aa 25 0d 01 00 00 5a 5a 00 00 00 00 00 00 00 00", .battery(Battery(percent: 90, isCharging: false))),
        ("aa 25 0d 01 01 01 32 32 00 00 00 00 00 00 00 00", .battery(Battery(percent: 50, isCharging: true))),
        ("aa 9d 03 02 01 02", .spatial(SpatialSetting(isOn: true, mode: .movie))),
        ("aa 9d 03 02 00 01", .spatial(SpatialSetting(isOn: false, mode: .music))),
        ("aa 9e 02 02 00", .lowVolumeEq(false)),
        ("aa 9e 02 02 01", .lowVolumeEq(true)),
        ("aa a8 05 02 01 00 02 64", .balance(Balance(offset: 0)!)),
        ("aa a8 05 02 01 01 02 60", .balance(Balance(offset: -4)!)),
    ]

    @Test(arguments: decodings)
    func decodesReply(hex: String, expected: Reply) throws {
        let frame = try Frame.decode(Data(hex: hex))

        #expect(Reply(frame: frame) == expected)
    }

    @Test(arguments: [EqPreset.studio, .bass])
    func decodesEqPresetReply(preset: EqPreset) throws {
        let payload = [0x04] + EqFrameBuilder.payload(for: preset).dropFirst()
        let frame = Frame(command: 0xA2, payload: Array(payload), usesWideLength: true)

        #expect(Reply(frame: frame) == .eq(.preset(preset)))
    }

    @Test func decodesCustomEqSlot() {
        let payload: [UInt8] = [0x04, 0xCA] + [UInt8](repeating: 0, count: 114)
        let frame = Frame(command: 0xA2, payload: payload, usesWideLength: true)

        #expect(Reply(frame: frame) == .eq(.custom(0xCA)))
    }

    @Test(
        arguments: [
            "aa 12 03 4a 42 4c",
            "aa 9b 03 02 01 00",
            "aa 91 01 13",
            "aa 91 07 22 01 01 04 04 05 01",
            "aa 91 07 12 01 01 02 01 03 00",
            "aa 91 03 12 01 01",
            "aa 91 03 22 a1 09",
            "aa 9d 03 02 01 07",
            "aa a8 05 02 01 01 02 10",
            "aa 25 02 01 00",
            "aa 9e 01 02",
        ]
    )
    func unknownFramesDecodeToUnknown(hex: String) throws {
        let frame = try Frame.decode(Data(hex: hex))

        #expect(Reply(frame: frame) == .unknown(frame))
    }

    @Test func emptyPayloadDecodesToUnknown() {
        let frame = Frame(command: 0x91, payload: [])

        #expect(Reply(frame: frame) == .unknown(frame))
    }

    @Test func replyKindMatchesCase() {
        #expect(Reply.noiseMode(.anc).kind == .noiseMode)
        #expect(Reply.lowVolumeEq(true).kind == .lowVolumeEq)
        #expect(Reply.unknown(Frame(command: 0x12, payload: [])).kind == nil)
    }

    static let expectations: [(Command, ReplyKind)] = [
        (.queryNoiseMode, .noiseMode),
        (.setNoiseMode(.off), .noiseMode),
        (.queryAdvancedAnc, .ambientLevel),
        (.setAmbientLevel(AmbientLevel(3)!), .ambientLevel),
        (.queryBattery, .battery),
        (.querySpatial, .spatial),
        (.setSpatial(SpatialSetting(isOn: true, mode: .music)), .spatial),
        (.queryLowVolumeEq, .lowVolumeEq),
        (.setLowVolumeEq(true), .lowVolumeEq),
        (.queryEq, .eq),
        (.setEqPreset(.jazz), .eq),
        (.queryBalance, .balance),
        (.setBalance(Balance(offset: 2)!), .balance),
    ]

    @Test(arguments: expectations)
    func commandExpectsMatchingReplyKind(command: Command, kind: ReplyKind) {
        #expect(command.expectedReply == kind)
    }

    @Test func queryForKindRoundTrips() {
        #expect(ReplyKind.allCases.allSatisfy { $0.query.expectedReply == $0 })
    }
}
