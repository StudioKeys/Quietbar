import CMFProtocol
import Foundation
import HeadphoneKit
import Testing

@testable import CMFDriver

struct CMFHeadphonesProDriverTests {
    private let driver = CMFHeadphonesProDriver { true }

    @Test func descriptorsMatchSupportedControls() {
        #expect(
            driver.model.settings.map(\.id) == [
                CMFSetting.noiseMode, CMFSetting.eqPreset, CMFSetting.spatialSound, CMFSetting.lowLag,
                CMFSetting.dualConnection,
            ])
        #expect(driver.model.link == .rfcomm(serviceUUID: CMFHeadphonesProDriver.serviceUUID))
        #expect(CMFHeadphonesProDriver.serviceUUID.uuidString.lowercased() == "aeac4a03-dff5-498f-843a-34487cf133eb")
    }

    @Test func noiseModesDecodeFromTriplePayload() {
        #expect(
            updates(.getNoiseControl, payload: [1, 4, 0, 2, 4, 0]) == [
                .setting(CMFSetting.noiseMode, .choice("4"))
            ])
        #expect(
            updates(.noiseControlChanged, payload: [1, 254, 0]) == [
                .setting(CMFSetting.noiseMode, .choice("7"))
            ])
    }

    @Test func noiseControlEncodesOfficialPayload() {
        let data = driver.requests(
            for: SettingChange(id: CMFSetting.noiseMode, value: .choice("4")), current: .empty)?.first

        #expect(frame(data)?.command == CMFCommand.setNoiseControl.rawValue)
        #expect(frame(data)?.payload == Data([1, 4, 0]))
    }

    @Test func eqPresetRoundTrips() {
        #expect(updates(.getEQPreset, payload: [9]) == [.setting(CMFSetting.eqPreset, .choice("9"))])
        let data = driver.requests(
            for: SettingChange(id: CMFSetting.eqPreset, value: .choice("6")), current: .empty)?.first

        #expect(frame(data)?.command == CMFCommand.setEQPreset.rawValue)
        #expect(frame(data)?.payload == Data([6]))
    }

    @Test func switchesEncodeAndDecode() {
        #expect(updates(.getLowLag, payload: [1]) == [.setting(CMFSetting.lowLag, .bool(true))])
        #expect(updates(.getLowLag, payload: [2]) == [.setting(CMFSetting.lowLag, .bool(false))])
        #expect(updates(.getSpatialAudio, payload: [1]) == [.setting(CMFSetting.spatialSound, .bool(true))])
        #expect(updates(.getDualConnection, payload: [0]) == [.setting(CMFSetting.dualConnection, .bool(false))])

        #expect(
            frame(
                driver.requests(
                    for: SettingChange(id: CMFSetting.lowLag, value: .bool(false)), current: .empty)?.first)?
                .payload == Data([2]))
    }

    @Test func stereoBatteryUsesChargingBit() {
        #expect(
            updates(.getBattery, payload: [6, 0xD2]) == [
                .battery(Battery(percent: 82, isCharging: true))
            ])
    }

    @Test func unsupportedValuesAreIgnored() {
        #expect(
            driver.requests(
                for: SettingChange(id: CMFSetting.eqPreset, value: .choice("12")), current: .empty) == nil)
        #expect(updates(.getEQPreset, payload: [12]).isEmpty)
        #expect(updates(.getNoiseControl, payload: [1, 99, 0]).isEmpty)
    }

    @Test func everyEditableSettingHasAConfirmingQuery() {
        for descriptor in driver.model.settings {
            #expect(driver.confirmingRequest(for: descriptor.id) != nil)
        }
    }

    @Test func dualConnectionReconnectionIsExplicit() {
        #expect(
            driver.model.settings.first { $0.id == CMFSetting.dualConnection }?.appliesWithReconnect == true)
    }

    @Test func experimentalWritesAreDisabledByDefault() {
        let readOnly = CMFHeadphonesProDriver()

        #expect(
            readOnly.requests(
                for: SettingChange(id: CMFSetting.lowLag, value: .bool(true)), current: .empty) == nil)
        #expect(readOnly.model.settings.allSatisfy { $0.requiresExperimentalWrites })
    }

    private func frame(_ data: Data?) -> CMFFrame? {
        guard let data else { return nil }
        return try? CMFFrame.decode(data)
    }

    private func updates(_ command: CMFCommand, payload: [UInt8]) -> [DeviceUpdate] {
        let response = CMFFrame(
            control: 0x0600,
            command: command.responseCommand,
            sequence: 1,
            payload: Data(payload)
        ).encoded()
        return driver.updates(from: response)
    }
}
