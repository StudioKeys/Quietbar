import CMFProtocol
import Foundation
import HeadphoneKit
import Testing

@testable import CMFDriver

struct CMFHeadphonesProDriverTests {
    private let driver = CMFHeadphonesProDriver()

    // Captured from a CMF Headphone Pro: bass +6, mid -6, treble 0.
    private static let customEQPayload = hexBytes(
        "030000c0c0010000c0c000007544c3f5283f020000000000c05a450000803f000000c04000000c43cdcc4c3f"
            + "00000000000000000042da")

    @Test func batteryReadsCountPrefixedPairs() {
        #expect(updates(.getBattery, [0x01, 0x06, 0x2D]) == [.battery(Battery(percent: 45, isCharging: false))])
        #expect(
            updates(.batteryChanged, [0x01, 0x06, 0xD2], response: false) == [
                .battery(Battery(percent: 82, isCharging: true))
            ])
    }

    @Test func noiseControlSplitsModeAndLevel() {
        #expect(
            updates(.getNoiseControl, [1, 1, 0, 2, 1, 0]) == [
                .setting(CMFSetting.noiseMode, .choice("anc")), .setting(CMFSetting.ancLevel, .choice("1")),
                .setting(CMFSetting.ancLevel, .choice("1")),
            ])
        #expect(
            updates(.noiseControlChanged, [1, 7, 0, 2, 2, 0], response: false) == [
                .setting(CMFSetting.noiseMode, .choice("transparency")), .setting(CMFSetting.ancLevel, .choice("2")),
            ])
        #expect(updates(.getNoiseControl, [1, 5, 0]) == [.setting(CMFSetting.noiseMode, .choice("off"))])
    }

    @Test func noiseCancellationRestoresLastLevel() {
        let current = DeviceState.empty.applying([.setting(CMFSetting.ancLevel, .choice("3"))])

        #expect(writePayload(CMFSetting.noiseMode, .choice("anc"), current: current) == [1, 3, 0])
        #expect(writePayload(CMFSetting.noiseMode, .choice("transparency")) == [1, 7, 0])
        #expect(writePayload(CMFSetting.ancLevel, .choice("4")) == [1, 4, 0])
    }

    @Test func spatialAudioIsAThreeWayMode() {
        #expect(updates(.getSpatialAudio, [0x02, 0x00]) == [.setting(CMFSetting.spatialMode, .choice("2"))])
        #expect(updates(.getSpatialAudio, [0x03, 0x00]) == [.setting(CMFSetting.spatialMode, .choice("3"))])
        #expect(updates(.getSpatialAudio, [0x00, 0x00]) == [.setting(CMFSetting.spatialMode, .choice("0"))])
        #expect(writePayload(CMFSetting.spatialMode, .choice("3")) == [3])
        #expect(writePayload(CMFSetting.spatialMode, .choice("1")) == nil)
    }

    @Test func eqPresetUsesDiracCommands() {
        #expect(updates(.getEQPreset, [0x06]) == [.setting(CMFSetting.eqPreset, .choice("6"))])
        let requests = driver.requests(
            for: SettingChange(id: CMFSetting.eqPreset, value: .choice("1")), current: .empty)

        #expect(frame(requests?.first)?.command == CMFCommand.setEQPreset.rawValue)
        #expect(frame(requests?.first)?.payload == Data([1]))
        #expect(frame(requests?.last)?.command == CMFCommand.getEQPreset.rawValue)
    }

    @Test func customEQDecodesBands() {
        #expect(
            updates(.getCustomEQ, Self.customEQPayload) == [
                .setting(CMFSetting.bass, .level(6)), .setting(CMFSetting.mid, .level(-6)),
                .setting(CMFSetting.treble, .level(0)),
            ])
    }

    @Test func customEQWriteEditsLastReadBlock() {
        _ = updates(.getCustomEQ, Self.customEQPayload)

        let payload = writePayload(CMFSetting.treble, .level(1))

        #expect(payload == Array(Self.customEQPayload.prefix(44)).replacing(at: 19, with: [0, 0, 0x80, 0x3F]))
    }

    @Test func consecutiveBandEditsBuildOnEachOther() {
        _ = updates(.getCustomEQ, Self.customEQPayload)
        _ = writePayload(CMFSetting.bass, .level(0))

        let payload = writePayload(CMFSetting.mid, .level(0)).map(CMFCustomEQ.decode)

        #expect(payload??.gain(.bass) == 0)
        #expect(payload??.gain(.mid) == 0)
        #expect(payload??.totalGain == 0)
    }

    @Test func customEQGainIsClampedAndPreGainTracksBoost() {
        let eq = CMFCustomEQ.factory.setting(.bass, to: 9)

        #expect(eq.gain(.bass) == 6)
        #expect(eq.totalGain == -6)
        #expect(CMFCustomEQ.decode(eq.encoded()) == eq)
    }

    @Test func nonFiniteOrOutOfRangeGainsAreSafe() {
        var nan = Self.customEQPayload
        nan.replaceSubrange(6..<10, with: Float.nan.bitPattern.littleEndianBytes)
        var infinite = Self.customEQPayload
        infinite.replaceSubrange(6..<10, with: Float.infinity.bitPattern.littleEndianBytes)
        var huge = Self.customEQPayload
        huge.replaceSubrange(6..<10, with: Float(1e12).bitPattern.littleEndianBytes)

        #expect(CMFCustomEQ.decode(nan) == nil)
        #expect(CMFCustomEQ.decode(infinite) == nil)
        #expect(updates(.getCustomEQ, nan).isEmpty)
        #expect(CMFCustomEQ.decode(huge)?.gain(.mid) == 6)
        #expect(CMFCustomEQ(filters: [.bass: .init(gain: .nan, frequency: 140, q: 0.8)]).gain(.bass) == 0)
    }

    @Test func staleReadBackDoesNotRevertNewerEdit() {
        _ = updates(.getCustomEQ, Self.customEQPayload)
        let first = writePayload(CMFSetting.bass, .level(0)).flatMap(CMFCustomEQ.decode)
        _ = writePayload(CMFSetting.treble, .level(3))

        // The bass write's confirmation arrives after the treble edit was sent.
        let confirmation = updates(.getCustomEQ, first.map { $0.encoded() } ?? [])
        let next = writePayload(CMFSetting.mid, .level(1)).flatMap(CMFCustomEQ.decode)

        #expect(confirmation.contains(.setting(CMFSetting.treble, .level(3))))
        #expect(next?.gain(.treble) == 3)
        #expect(next?.gain(.bass) == 0)
    }

    @Test func unconfirmedEditExpires() {
        let clock = TestClock()
        let driver = CMFHeadphonesProDriver(customEQ: CMFCustomEQCache(now: { clock.now }))
        _ = driver.requests(for: SettingChange(id: CMFSetting.bass, value: .level(4)), current: .empty)
        clock.advance(CMFCustomEQCache.editLifetime + 1)

        let reported = CMFCustomEQ.factory.setting(.treble, to: -2)
        let response = CMFFrame(
            control: 0x0600, command: CMFCommand.getCustomEQ.responseCommand, sequence: 1,
            payload: Data(reported.encoded())
        ).encoded()

        #expect(driver.updates(from: response).contains(.setting(CMFSetting.bass, .level(0))))
    }

    @Test func lowLagRoundTrips() {
        #expect(updates(.getLowLag, [1]) == [.setting(CMFSetting.lowLag, .bool(true))])
        #expect(updates(.getLowLag, [2]) == [.setting(CMFSetting.lowLag, .bool(false))])
        #expect(writePayload(CMFSetting.lowLag, .bool(false)) == [2])
    }

    @Test func writesAreFollowedByTheirQuery() {
        for descriptor in driver.model.settings {
            #expect(driver.confirmingRequest(for: descriptor.id) != nil)
        }
        let requests = driver.requests(
            for: SettingChange(id: CMFSetting.spatialMode, value: .choice("2")), current: .empty)
        #expect(requests?.count == 2)
        #expect(frame(requests?.last)?.command == CMFCommand.getSpatialAudio.rawValue)
    }

    @Test func dualConnectionAppliesWithReconnect() {
        #expect(driver.model.settings.first { $0.id == CMFSetting.dualConnection }?.appliesWithReconnect == true)
        #expect(writePayload(CMFSetting.dualConnection, .bool(false)) == [0])
    }

    @Test func malformedPayloadsAreIgnored() {
        #expect(updates(.getBattery, []).isEmpty)
        #expect(updates(.getBattery, [0x02, 0x06]).isEmpty)
        #expect(updates(.getCustomEQ, [0x03, 0x00]).isEmpty)
        #expect(updates(.getEQPreset, [0x0C]).isEmpty)
        #expect(updates(.getNoiseControl, [1, 99, 0]).isEmpty)
    }

    private func writePayload(_ id: SettingID, _ value: SettingValue, current: DeviceState = .empty) -> [UInt8]? {
        frame(driver.requests(for: SettingChange(id: id, value: value), current: current)?.first)
            .map { [UInt8]($0.payload) }
    }

    private func frame(_ data: Data?) -> CMFFrame? {
        data.flatMap { try? CMFFrame.decode($0) }
    }

    private func updates(_ command: CMFCommand, _ payload: [UInt8], response: Bool = true) -> [DeviceUpdate] {
        let code = response ? command.responseCommand : command.rawValue
        return driver.updates(
            from: CMFFrame(control: 0x0600, command: code, sequence: 1, payload: Data(payload)).encoded())
    }

    private static func hexBytes(_ text: String) -> [UInt8] {
        stride(from: 0, to: text.count, by: 2).map {
            UInt8(text.dropFirst($0).prefix(2), radix: 16)!
        }
    }
}

private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 0)

    var now: Date { lock.withLock { current } }

    func advance(_ interval: TimeInterval) {
        lock.withLock { current.addTimeInterval(interval) }
    }
}

extension UInt32 {
    fileprivate var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: littleEndian, Array.init)
    }
}

extension Array where Element == UInt8 {
    fileprivate func replacing(at offset: Int, with bytes: [UInt8]) -> [UInt8] {
        var copy = self
        copy.replaceSubrange(offset..<(offset + bytes.count), with: bytes)
        return copy
    }
}
