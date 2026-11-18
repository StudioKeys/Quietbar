import Foundation

@testable import HeadphoneKit

protocol DeviceSessionHarness {}

extension DeviceSessionHarness {
    static var hello: Data { Data([0x09]) }

    static var identity: DeviceIdentity {
        DeviceIdentity(name: "Jis Cans", linkID: "LINK-1", classicAddress: nil)
    }

    var handshakeDriver: FakeDriver {
        var driver = FakeDriver()
        driver.handshakeRequests = [Self.hello]
        driver.readySetting = "mode"
        return driver
    }

    func makeSession(
        _ transport: FakeByteTransport,
        timeout: Duration = .milliseconds(50),
        store: InMemoryPreferenceStore = InMemoryPreferenceStore(),
        sleeper: ScriptedSleeper = ScriptedSleeper(immediateCount: 0),
        watcher: FakeConnectionWatcher? = nil,
        deviceID: String? = nil,
        driver: FakeDriver = FakeDriver()
    ) -> DeviceSession {
        DeviceSession(
            driver: driver,
            transport: transport,
            replyTimeout: timeout,
            sleep: sleeper.closure,
            preferences: store,
            watcher: watcher,
            deviceID: deviceID
        )
    }

    func storedIdentity(_ store: InMemoryPreferenceStore, _ id: String = "dev") -> DeviceIdentity? {
        store.string(forKey: DeviceSession.identityKey(for: id)).flatMap(DeviceIdentity.decode)
    }
}
