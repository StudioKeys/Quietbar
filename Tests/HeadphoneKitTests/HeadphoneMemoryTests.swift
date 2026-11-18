import Testing

@testable import HeadphoneKit

struct HeadphoneMemoryTests {
    private let link = DeviceIdentity(name: "JBL Live 770NC-LE", linkID: "LINK-1", classicAddress: nil)
    private let audio = ClassicConnection(name: "JBL Live 770NC", address: "AA")

    @Test func matchesByNameFragmentUntilAddressKnown() {
        let memory = HeadphoneMemory(identity: nil, nameFragment: "770NC")

        #expect(memory.isOurs(audio))
        #expect(!memory.isOurs(ClassicConnection(name: "Keyboard", address: "BB")))
    }

    @Test func matchesOnlyByAddressOnceKnown() {
        let known = DeviceIdentity(name: "x", linkID: "LINK-1", classicAddress: "AA", classicName: "Jis Cans")
        let memory = HeadphoneMemory(identity: known, nameFragment: "770NC")

        #expect(memory.isOurs(ClassicConnection(name: "Renamed", address: "AA")))
        #expect(!memory.isOurs(ClassicConnection(name: "JBL Live 770NC", address: "BB")))
    }

    @Test func audioSeenBeforeLinkIsAttachedOnConnect() {
        var memory = HeadphoneMemory(identity: nil, nameFragment: "770NC")

        memory.noteClassic(audio)
        memory.connected(as: link)

        #expect(memory.identity?.classicAddress == "AA")
        #expect(memory.identity?.classicName == "JBL Live 770NC")
        #expect(memory.identity?.linkID == "LINK-1")
    }

    @Test func displayNamePrefersAudioName() {
        var memory = HeadphoneMemory(identity: nil, nameFragment: "770NC")
        memory.connected(as: link)
        #expect(memory.displayName == "JBL Live 770NC-LE")

        memory.noteClassic(audio)

        #expect(memory.displayName == "JBL Live 770NC")
    }

    @Test func renameOfKnownDeviceUpdatesName() {
        var memory = HeadphoneMemory(
            identity: DeviceIdentity(name: "x", linkID: "LINK-1", classicAddress: "AA", classicName: "JBL Live 770NC"),
            nameFragment: "770NC")

        memory.noteClassic(ClassicConnection(name: "Jis Cans", address: "AA"))

        #expect(memory.displayName == "Jis Cans")
    }

    @Test func reconnectKeepsLearnedAudioDetails() {
        var memory = HeadphoneMemory(
            identity: DeviceIdentity(name: "x", linkID: "LINK-1", classicAddress: "AA", classicName: "Jis Cans"),
            nameFragment: "770NC")

        memory.connected(as: link)

        #expect(memory.identity?.classicAddress == "AA")
        #expect(memory.displayName == "Jis Cans")
    }
}
