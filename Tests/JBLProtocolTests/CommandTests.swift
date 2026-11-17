import Foundation
import Testing

@testable import JBLProtocol

struct CommandTests {
    static let encodings: [(Command, String)] = [
        (.queryNoiseMode, "aa 91 01 11"),
        (.setNoiseMode(.anc), "aa 91 07 10 01 01 02 00 03 00"),
        (.setNoiseMode(.ambientAware), "aa 91 07 10 01 00 02 01 03 00"),
        (.setNoiseMode(.talkThru), "aa 91 07 10 01 00 02 00 03 01"),
        (.setNoiseMode(.off), "aa 91 01 13"),
        (.queryAdvancedAnc, "aa 91 01 21"),
        (.setAmbientLevel(AmbientLevel(5)!), "aa 91 03 20 a1 05"),
        (.queryBattery, "aa 25 01 00"),
        (.querySpatial, "aa 9d 01 01"),
        (.setSpatial(SpatialSetting(isOn: true, mode: .game)), "aa 9d 03 00 01 03"),
        (.queryLowVolumeEq, "aa 9e 01 01"),
        (.setLowVolumeEq(false), "aa 9e 02 00 00"),
        (.queryEq, "aa a2 02 01 ff"),
        (.queryBalance, "aa a8 01 01"),
        (.setBalance(Balance(offset: -4)!), "aa a8 05 00 01 01 02 60"),
        (.setBalance(Balance(offset: 0)!), "aa a8 05 00 01 00 02 64"),
    ]

    @Test(arguments: encodings)
    func encodesCommand(command: Command, hex: String) {
        #expect(command.frame.encoded() == Data(hex: hex))
    }

    @Test func setEqPresetMatchesCapturedBassFrame() {
        let captured = Data(
            hex: """
                aa a2 74 00 03 03 00 00 00 00 30 00 00 00 00 00 00 00 00 \
                0a 01 00 00 80 40 00 00 00 42 0a 01 00 00 80 40 00 00 80 42 \
                0a 01 00 00 40 40 00 00 fa 42 0a 01 00 00 20 40 00 00 7a 43 \
                0a 01 00 00 00 3f 00 00 fa 43 0a 01 00 00 00 00 00 00 7a 44 \
                0a 01 00 00 00 00 00 00 fa 44 0a 01 00 00 00 00 00 00 7a 45 \
                0a 01 00 00 00 00 00 00 fa 45 0a 01 00 00 00 00 00 00 7a 46 0a
                """
        )

        #expect(Command.setEqPreset(.bass).frame.encoded() == captured)
    }

    @Test(arguments: EqPreset.allCases)
    func everyEqFrameHasCapturedLength(preset: EqPreset) {
        #expect(Command.setEqPreset(preset).frame.payload.count == 116)
    }

    @Test func noCommandTargetsOtaCommand() {
        let commands = Self.encodings.map(\.0) + EqPreset.allCases.map(Command.setEqPreset)

        #expect(commands.allSatisfy { $0.frame.command != 0xF0 })
    }

    @Test func refreshAllQueriesEverySettingInOrder() {
        #expect(
            Command.refreshAll == [
                .queryNoiseMode, .queryAdvancedAnc, .queryBattery, .querySpatial,
                .queryLowVolumeEq, .queryEq, .queryBalance,
            ]
        )
    }
}
