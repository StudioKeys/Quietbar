import Foundation

public struct GattProfile: Hashable, Sendable {
    public let service: String
    public let notify: String
    public let write: String
    public let nameFragment: String

    public init(service: String, notify: String, write: String, nameFragment: String) {
        self.service = service
        self.notify = notify
        self.write = write
        self.nameFragment = nameFragment
    }
}

public struct DeviceModel: Hashable, Sendable {
    public let name: String
    public let gatt: GattProfile
    public let settings: [SettingDescriptor]

    public init(name: String, gatt: GattProfile, settings: [SettingDescriptor]) {
        self.name = name
        self.gatt = gatt
        self.settings = settings
    }
}

extension SettingID {
    public static let battery: SettingID = "battery"
}

public protocol DeviceDriver: Sendable {
    var model: DeviceModel { get }
    var refreshRequests: [Data] { get }
    func requests(for change: SettingChange, current: DeviceState) -> [Data]?
    func confirmingRequest(for setting: SettingID) -> Data?
    func updates(from packet: Data) -> [DeviceUpdate]
}

public protocol DeviceTransport: Sendable {
    var incoming: AsyncStream<Data> { get }
    var events: AsyncStream<LinkEvent> { get }
    func connect() async throws(TransportError)
    func disconnect() async
    func send(_ data: Data) async throws(TransportError)
}
