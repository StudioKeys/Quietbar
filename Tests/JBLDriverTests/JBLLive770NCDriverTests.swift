import Foundation
import HeadphoneKit
import Testing

@testable import JBLDriver

struct JBLLive770NCDriverTests {
    private let driver = JBLLive770NCDriver()

    private func requests(_ id: SettingID, _ value: SettingValue, state: DeviceState = .empty) -> [String]? {
        driver.requests(for: SettingChange(id: id, value: value), current: state)?.map(\.hexString)
    }

    @Test(
        arguments: [
            ("noiseMode", SettingValue.choice("anc"), "aa 91 07 10 01 01 02 00 03 00"),
            ("noiseMode", .choice("off"), "aa 91 01 13"),
            ("adaptiveAnc", .bool(true), "aa 91 03 20 01 01"),
            ("adaptiveAnc", .bool(false), "aa 91 03 20 01 00"),
            ("leakageCompensation", .bool(false), "aa 91 03 20 05 00"),
            ("ambientLevel", .level(5), "aa 91 03 20 a1 05"),
            ("lowVolumeEq", .bool(true), "aa 9e 02 00 01"),
            ("balance", .level(-4), "aa a8 05 00 01 01 02 60"),
            ("autoPlayPause", .bool(true), "aa 35 01 01"),
            ("autoPlayPause", .bool(false), "aa 35 01 00"),
            ("smartAudioVideo", .bool(false), "aa 81 08 00 01 2e 00 b4 00 ff ff"),
            ("smartAudioVideoMode", .choice("audio"), "aa 81 08 00 01 35 00 96 00 ff ff"),
            ("smartAudioVideoMode", .choice("video"), "aa 81 08 c5 00 2e 00 64 00 ff ff"),
        ] as [(SettingID, SettingValue, String)]
    )
    func encodesChange(id: SettingID, value: SettingValue, hex: String) {
        #expect(requests(id, value) == [hex])
    }

    @Test func eqPresetEncodesFullFrame() throws {
        let frames = try #require(requests("eqPreset", .choice("bass")))

        #expect(frames.count == 1)
        #expect(frames[0].hasPrefix("aa a2 74 00 03 03"))
    }

    @Test func smartAudioVideoOnUsesCurrentMode() {
        let state = DeviceState.empty.applying([.setting("smartAudioVideoMode", .choice("video"))])

        #expect(requests("smartAudioVideo", .bool(true), state: state) == ["aa 81 08 c5 00 2e 00 64 00 ff ff"])
    }

    @Test func smartAudioVideoOnDefaultsToAudioMode() {
        #expect(requests("smartAudioVideo", .bool(true)) == ["aa 81 08 00 01 35 00 96 00 ff ff"])
    }

    @Test func spatialToggleKeepsSelectedMode() {
        let state = DeviceState.empty.applying([.setting("spatialMode", .choice("game"))])

        #expect(requests("spatialSound", .bool(false), state: state) == ["aa 9d 03 00 00 03"])
    }

    @Test func spatialModeTurnsSpatialOn() {
        #expect(requests("spatialMode", .choice("movie")) == ["aa 9d 03 00 01 02"])
    }

    @Test(
        arguments: [
            ("ambientLevel", SettingValue.level(9)),
            ("balance", .level(40)),
            ("noiseMode", .choice("loud")),
            ("eqPreset", .choice("custom")),
            ("adaptiveAnc", .level(1)),
            ("unknownSetting", .bool(true)),
        ] as [(SettingID, SettingValue)]
    )
    func rejectsInvalidChange(id: SettingID, value: SettingValue) {
        #expect(requests(id, value) == nil)
    }

    @Test(
        arguments: [
            ("aa 91 07 12 01 00 02 01 03 00", [DeviceUpdate.setting("noiseMode", .choice("ambientAware"))]),
            (
                "aa 91 09 22 01 01 04 04 05 01 a1 07",
                [
                    .setting("adaptiveAnc", .bool(true)), .setting("leakageCompensation", .bool(true)),
                    .setting("ambientLevel", .level(7)),
                ]
            ),
            (
                "aa 91 05 22 01 00 05 00",
                [.setting("adaptiveAnc", .bool(false)), .setting("leakageCompensation", .bool(false))]
            ),
            ("aa 25 0d 01 00 00 5a 5a 00 00 00 00 00 00 00 00", [.battery(Battery(percent: 90, isCharging: false))]),
            ("aa 9d 03 02 01 03", [.setting("spatialSound", .bool(true)), .setting("spatialMode", .choice("game"))]),
            ("aa 9e 02 02 00", [.setting("lowVolumeEq", .bool(false))]),
            ("aa a8 05 02 01 01 02 6a", [.setting("balance", .level(6))]),
            (
                "aa 83 08 00 01 35 00 96 00 ff ff",
                [.setting("smartAudioVideo", .bool(true)), .setting("smartAudioVideoMode", .choice("audio"))]
            ),
            (
                "aa 83 08 c5 00 2e 00 64 00 ff ff",
                [.setting("smartAudioVideo", .bool(true)), .setting("smartAudioVideoMode", .choice("video"))]
            ),
            ("aa 83 08 00 01 2e 00 b4 00 ff ff", [.setting("smartAudioVideo", .bool(false))]),
            ("aa 83 08 11 11 11 11 11 11 ff ff", []),
            ("aa 22 0d 30 00 02 ff 07 df 01 00 01 00 01 1e 00", [.setting("autoPlayPause", .bool(true))]),
            ("aa 22 0d 30 00 02 ff 07 df 01 00 00 00 01 1e 00", [.setting("autoPlayPause", .bool(false))]),
            ("aa 22 03 30 00 02", []),
            ("aa 9b 03 02 01 00", []),
            ("ab 91 01 11", []),
            ("aa 91", []),
        ] as [(String, [DeviceUpdate])]
    )
    func decodesPacket(hex: String, expected: [DeviceUpdate]) {
        #expect(driver.updates(from: Data(hex: hex)) == expected)
    }

    @Test func decodesEqPresetAndCustomSlot() {
        let studio = Data(hex: "aa a2 74 00 04 07") + Data(repeating: 0, count: 114)
        let custom = Data(hex: "aa a2 74 00 04 ca") + Data(repeating: 0, count: 114)

        #expect(driver.updates(from: studio) == [.setting("eqPreset", .choice("studio"))])
        #expect(driver.updates(from: custom) == [.setting("eqPreset", .choice("custom"))])
    }

    @Test func refreshRequestsCoverEverySetting() {
        let hex = driver.refreshRequests.map(\.hexString)

        #expect(
            hex == [
                "aa 91 01 11", "aa 91 01 21", "aa 25 01 00", "aa 9d 01 01", "aa 9e 01 01", "aa a2 02 01 ff",
                "aa a8 01 01", "aa 82 00", "aa 21 01 30",
            ]
        )
    }

    @Test(
        arguments: [
            ("noiseMode", "aa 91 01 11"), ("adaptiveAnc", "aa 91 01 21"), ("leakageCompensation", "aa 91 01 21"),
            ("ambientLevel", "aa 91 01 21"), ("eqPreset", "aa a2 02 01 ff"), ("spatialSound", "aa 9d 01 01"),
            ("spatialMode", "aa 9d 01 01"), ("lowVolumeEq", "aa 9e 01 01"), ("balance", "aa a8 01 01"),
            ("smartAudioVideo", "aa 82 00"), ("smartAudioVideoMode", "aa 82 00"), ("autoPlayPause", "aa 21 01 30"),
            ("battery", "aa 25 01 00"),
        ] as [(SettingID, String)]
    )
    func confirmingRequestPerSetting(id: SettingID, hex: String) {
        #expect(driver.confirmingRequest(for: id)?.hexString == hex)
    }

    @Test func everyDescriptorHasConfirmingRequest() {
        #expect(driver.model.settings.allSatisfy { driver.confirmingRequest(for: $0.id) != nil })
    }

    @Test func descriptorsMatchSpecOrderAndConditions() {
        let settings = driver.model.settings

        #expect(
            settings.map(\.id.rawValue) == [
                "noiseMode", "adaptiveAnc", "leakageCompensation", "ambientLevel", "eqPreset", "spatialSound",
                "spatialMode", "lowVolumeEq", "balance", "smartAudioVideo", "smartAudioVideoMode", "autoPlayPause",
            ]
        )
        #expect(settings[1].visibleWhen == .equals("noiseMode", .choice("anc")))
        #expect(settings[3].visibleWhen == .equals("noiseMode", .choice("ambientAware")))
        #expect(settings[6].visibleWhen == .equals("spatialSound", .bool(true)))
        #expect(settings[10].visibleWhen == .equals("smartAudioVideo", .bool(true)))
        #expect(settings[8].kind == .level(-16...16, style: .balance))
        #expect(driver.model.name == "JBL Live 770NC")
        #expect(driver.model.nameFragment == "770NC")
    }

    @Test func onlySmartAudioVideoSettingsReconnect() {
        let reconnecting = driver.model.settings.filter(\.appliesWithReconnect).map(\.id.rawValue)

        #expect(reconnecting == ["smartAudioVideo", "smartAudioVideoMode"])
    }

    @Test func noRequestUsesOtaCommand() {
        let all = driver.refreshRequests + driver.model.settings.compactMap { driver.confirmingRequest(for: $0.id) }

        #expect(all.allSatisfy { $0.count > 1 && $0[1] != 0xF0 })
    }
}

extension Data {
    var hexString: String { map { String(format: "%02x", $0) }.joined(separator: " ") }
}
