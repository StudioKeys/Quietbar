import Foundation
import HeadphoneKit
import MotoProtocol
import Testing

@testable import MotoDriver

struct MotoBudsPlusDriverTests {
    private let driver = MotoBudsPlusDriver()

    private func packet(_ opcode: MotoOpcode, _ payload: [UInt8], type: UInt8 = 0x20) -> Data {
        MotoFrame.encode(MotoPDU(opcode: opcode.rawValue, type: type, result: 0, seq: 0, payload: Data(payload)))
    }

    private func command(_ opcode: MotoOpcode, _ payload: [UInt8] = []) -> Data {
        MotoFrame.encode(.command(opcode, payload: payload))
    }

    @Test(arguments: [
        ([UInt8]([0x01, 0x03]), "anc"), ([0x01, 0x01], "adaptive"), ([0x02, 0x00], "transparency"),
        ([0x00, 0x00], "off"),
    ])
    func noiseControlDecodes(payload: [UInt8], mode: String) {
        let expected: [DeviceUpdate] = [.setting(MotoSetting.noiseMode, .choice(mode))]

        #expect(driver.updates(from: packet(.noiseControl, payload)) == expected)
        #expect(driver.updates(from: packet(.noiseControlChanged, payload, type: 0x40)) == expected)
    }

    @Test(arguments: [
        ("anc", [UInt8]([0x01, 0x03])), ("adaptive", [0x01, 0x01]), ("transparency", [0x02, 0x00]),
        ("off", [0x00, 0x00]),
    ])
    func noiseControlEncodes(mode: String, payload: [UInt8]) {
        let change = SettingChange(id: MotoSetting.noiseMode, value: .choice(mode))

        #expect(driver.requests(for: change, current: .empty) == [command(.setNoiseControl, payload)])
    }

    @Test func eqPresetRoundTrips() {
        #expect(
            driver.updates(from: packet(.eqSetChanged, [0x3f], type: 0x40))
                == [.setting(MotoSetting.eqPreset, .choice("63"))])
        #expect(
            driver.requests(for: SettingChange(id: MotoSetting.eqPreset, value: .choice("2")), current: .empty)
                == [command(.setEQSet, [0x02])])
    }

    @Test func unknownEqPresetIsIgnored() {
        #expect(driver.updates(from: packet(.eqSet, [0x00])).isEmpty)
    }

    @Test func hiResReadsLastByte() {
        #expect(
            driver.updates(from: packet(.hiResChanged, [0x01, 0x01], type: 0x40)) == [
                .setting(MotoSetting.hiRes, .bool(true))
            ])
        #expect(driver.updates(from: packet(.hiRes, [0x00])) == [.setting(MotoSetting.hiRes, .bool(false))])
    }

    @Test(arguments: [
        (MotoOpcode.gameModeChanged, MotoSetting.gameMode), (.volumeBoostChanged, MotoSetting.volumeBoost),
        (.inEarDetectionChanged, MotoSetting.inEarDetection),
    ])
    func switchNotificationsDecode(opcode: MotoOpcode, setting: SettingID) {
        #expect(driver.updates(from: packet(opcode, [0x01], type: 0x40)) == [.setting(setting, .bool(true))])
    }

    @Test func dualConnectionRoundTrips() {
        #expect(
            driver.updates(from: packet(.dualConnectionChanged, [0x01, 0x01], type: 0x40))
                == [.setting(MotoSetting.dualConnection, .bool(true))])
        #expect(
            driver.updates(from: packet(.dualConnectionChanged, [0x01, 0x00], type: 0x40))
                == [.setting(MotoSetting.dualConnection, .bool(false))])
        #expect(
            driver.requests(for: SettingChange(id: MotoSetting.dualConnection, value: .bool(false)), current: .empty)
                == [command(.setDualConnection, [0x01, 0x00])])
    }

    @Test func spatialAudioRoundTrips() {
        #expect(
            driver.updates(from: packet(.spatialAudioChanged, [0x01, 0x00], type: 0x40))
                == [.setting(MotoSetting.spatialSound, .bool(true))])
        #expect(
            driver.requests(for: SettingChange(id: MotoSetting.spatialSound, value: .bool(true)), current: .empty)
                == [command(.setSpatialAudio, [0x01, 0x00])])
    }

    @Test func batteryDecodesBudsAndCase() {
        let expected = Battery.buds(
            left: BatteryLevel(percent: 77, isCharging: false), right: BatteryLevel(percent: 72, isCharging: false),
            caseLevel: nil)!

        #expect(driver.updates(from: packet(.batteryLevel, [0x4d, 0x48, 0xff])) == [.battery(expected)])
    }

    @Test func chargingBitIsDecoded() {
        let updates = driver.updates(from: packet(.batteryChanged, [0xcd, 0x48, 0x28], type: 0x40))

        guard case .battery(let battery) = updates.first else {
            Issue.record("no battery")
            return
        }
        #expect(battery.left == BatteryLevel(percent: 77, isCharging: true))
        #expect(battery.caseLevel == BatteryLevel(percent: 40, isCharging: false))
    }

    @Test func emptySetAcknowledgementsAreIgnored() {
        #expect(driver.updates(from: packet(.setNoiseControl, [])).isEmpty)
        #expect(driver.updates(from: Data([0x00, 0x01])).isEmpty)
    }

    @Test func hiResAppliesWithReconnect() {
        #expect(driver.model.settings.first { $0.id == MotoSetting.hiRes }?.appliesWithReconnect == true)
    }

    @Test func handshakeAndReadiness() {
        #expect(
            driver.handshakeRequests == [
                command(.profileVersion), command(.supportFeatures),
                command(.listSupportInfo, [0xfc, 0xff, 0x05, 0x00]),
            ])
        #expect(!driver.isReady(.empty))
        let ready = DeviceState.empty.applying([
            .setting(MotoSetting.noiseMode, .choice("anc")), .setting(MotoSetting.eqPreset, .choice("1")),
        ])
        #expect(driver.isReady(ready))
    }

    @Test func descriptorsMatchPlan() {
        #expect(
            driver.model.settings.map(\.id) == [
                MotoSetting.noiseMode, MotoSetting.eqPreset, MotoSetting.spatialSound, MotoSetting.hiRes,
                MotoSetting.volumeBoost, MotoSetting.gameMode, MotoSetting.inEarDetection, MotoSetting.dualConnection,
            ])
        #expect(driver.model.link == .rfcomm(serviceUUID: MotoBudsPlusDriver.serviceUUID))
        #expect(MotoBudsPlusDriver.serviceUUID.uuidString.lowercased() == "fc9d9fe0-4899-11ee-be56-0242ac120002")
        #expect(driver.model.nameFragment == "moto buds")
        #expect(driver.model.symbol == "earbuds.case.fill")
        #expect(driver.model.groupsToggles)
    }

    @Test func eqPresetsAreIconTiles() throws {
        let eq = try #require(driver.model.settings.first { $0.id == MotoSetting.eqPreset })
        guard case .choice(let options, style: .pills) = eq.kind else {
            Issue.record("EQ preset should use pill tiles")
            return
        }

        #expect(options.allSatisfy { $0.symbol != nil })
    }

    @Test func everySettingHasAConfirmingQuery() {
        for descriptor in driver.model.settings {
            #expect(driver.confirmingRequest(for: descriptor.id) != nil)
        }
        #expect(driver.confirmingRequest(for: .battery) == command(.batteryLevel))
    }
}
