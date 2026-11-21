import Foundation

public struct GattProfile: Hashable, Sendable {
    public let service: String
    public let notify: String
    public let write: String

    public init(service: String, notify: String, write: String) {
        self.service = service
        self.notify = notify
        self.write = write
    }
}

public enum LinkProfile: Hashable, Sendable {
    case gatt(GattProfile)
    case rfcomm(serviceUUID: UUID)
}

public struct DeviceModel: Hashable, Sendable {
    public let name: String
    public let nameFragment: String
    public let link: LinkProfile
    public let settings: [SettingDescriptor]
    /// Identifies product artwork the app can draw instead of a generic SF Symbol.
    public let glyph: String?
    /// Renders a section's toggles together as compact rows after its other controls, instead of in place.
    public let groupsToggles: Bool

    public init(
        name: String, nameFragment: String, link: LinkProfile, settings: [SettingDescriptor], glyph: String? = nil,
        groupsToggles: Bool = false
    ) {
        self.name = name
        self.nameFragment = nameFragment
        self.link = link
        self.settings = settings
        self.glyph = glyph
        self.groupsToggles = groupsToggles
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
    var handshakeRequests: [Data] { get }
    func isReady(_ state: DeviceState) -> Bool
    func makeFramer() -> any PacketFramer
}

extension DeviceDriver {
    public var handshakeRequests: [Data] { [] }
    public func isReady(_ state: DeviceState) -> Bool { true }
    public func makeFramer() -> any PacketFramer { PassthroughFramer() }
}

public protocol DeviceTransport: Sendable {
    var incoming: AsyncStream<Data> { get }
    var events: AsyncStream<LinkEvent> { get }
    func connect() async throws(TransportError)
    func disconnect() async
    func send(_ data: Data) async throws(TransportError)
    func connectedIdentity() async -> DeviceIdentity?
    func remember(_ identity: DeviceIdentity?) async
}
