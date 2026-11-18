import Testing

@testable import HeadphoneKit

struct DeviceSessionIdentityTests: DeviceSessionHarness {
    @Test func userConnectRestoresRememberedIdentity() async {
        let store = InMemoryPreferenceStore()
        store.set(Self.identity.encoded, forKey: DeviceSession.identityKey(for: "dev"))
        store.set(false, forKey: DeviceSession.connectionKey(for: "dev"))
        let transport = FakeByteTransport()
        let session = makeSession(transport, store: store, deviceID: "dev")

        await session.userConnect()

        #expect(await transport.rememberedAtFirstConnect == Self.identity)
        #expect(await session.current.deviceName == "Jis Cans")
    }

    @Test func identityRememberedAfterConnect() async {
        let store = InMemoryPreferenceStore()
        let transport = FakeByteTransport(identity: Self.identity)

        let session = makeSession(transport, store: store, deviceID: "dev")
        await session.start()

        #expect(storedIdentity(store) == Self.identity)
        #expect(await session.current.deviceName == "Jis Cans")
    }

    @Test func rememberedIdentityPassedToTransportOnStart() async throws {
        let store = InMemoryPreferenceStore()
        store.set(Self.identity.encoded, forKey: DeviceSession.identityKey(for: "dev"))
        let transport = FakeByteTransport(holdsConnect: true)
        let session = makeSession(transport, store: store, deviceID: "dev")

        let starting = Task { await session.start() }
        defer { starting.cancel() }

        try await waitUntil { await transport.connectCount == 1 }
        #expect(await transport.remembered == Self.identity)
        #expect(await session.current.deviceName == "Jis Cans")
    }

    @Test func audioNameReportedBeforeStartNamesTheHeadphones() async throws {
        let store = InMemoryPreferenceStore()
        let transport = FakeByteTransport(identity: Self.identity)
        let watcher = FakeConnectionWatcher()
        watcher.emit("Fake Phones", address: "CC")
        let session = makeSession(transport, store: store, watcher: watcher, deviceID: "dev")

        await session.start()
        try await waitUntil { await session.current.deviceName == "Fake Phones" }

        #expect(await session.current.deviceName == "Fake Phones")
        #expect(storedIdentity(store)?.classicAddress == "CC")
    }

    @Test func sessionsUsePerDeviceKey() async {
        let store = InMemoryPreferenceStore()
        store.set(false, forKey: DeviceSession.connectionKey(for: "a"))
        let other = FakeByteTransport()

        await makeSession(other, store: store, deviceID: "b").start()

        #expect(await other.connectCount == 1)
    }
}
