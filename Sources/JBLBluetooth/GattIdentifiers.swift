import CoreBluetooth

enum GattIdentifiers {
    static let deviceNameFragment = "770NC"
    static let connectTimeout: TimeInterval = 20

    static var service: CBUUID { CBUUID(string: "65786365-6c70-6f69-6e74-2e636f6d0000") }
    static var notify: CBUUID { CBUUID(string: "65786365-6c70-6f69-6e74-2e636f6d0001") }
    static var write: CBUUID { CBUUID(string: "65786365-6c70-6f69-6e74-2e636f6d0002") }
}
