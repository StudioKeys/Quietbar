import HeadphoneKit
import Testing

@testable import Quietbar

struct StatusTextTests {
    @Test(
        arguments: [
            (ConnectionStatus.idle, "Starting…"),
            (.searching, "Searching…"),
            (.connected, "Connected"),
            (.disconnectedByUser, "Disconnected"),
            (.retrying(after: .seconds(5), phoneHint: true), "Disconnected — phone app may hold the link"),
            (.retrying(after: .seconds(5), phoneHint: false), "Searching…"),
            (.unavailable(.poweredOff), "Bluetooth off"),
            (.unavailable(.unauthorized), "Bluetooth permission needed"),
            (.unavailable(.unsupported), "Bluetooth LE not supported"),
        ]
    )
    func statusTextCopy(status: ConnectionStatus, text: String) {
        #expect(StatusText.describe(status, deviceName: "Test Phones") == text)
    }

    @Test func waitingNamesDevice() {
        #expect(
            StatusText.describe(.waiting, deviceName: "JBL Live 770NC")
                == "Waiting for JBL Live 770NC — turn it on or connect it")
    }
}
