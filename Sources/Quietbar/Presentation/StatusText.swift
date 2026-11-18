import HeadphoneKit

enum StatusText {
    static func describe(_ status: ConnectionStatus) -> String {
        switch status {
        case .idle: "Starting…"
        case .searching, .retrying(_, phoneHint: false): "Searching…"
        case .connected: "Connected"
        case .disconnectedByUser, .waiting: "Disconnected"
        case .retrying(_, phoneHint: true): "Disconnected — phone app may hold the link"
        case .unavailable(let issue): describe(issue)
        }
    }

    private static func describe(_ issue: BluetoothIssue) -> String {
        switch issue {
        case .poweredOff: "Bluetooth off"
        case .unauthorized: "Bluetooth permission needed"
        case .unsupported: "Bluetooth LE not supported"
        }
    }
}
