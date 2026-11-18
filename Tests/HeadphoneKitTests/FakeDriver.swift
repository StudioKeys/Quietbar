import Foundation
import HeadphoneKit

struct FakeDriver: DeviceDriver {
    static let settings: [SettingID] = ["power", "volume", "mode", "codec"]

    let model = DeviceModel(
        name: "Fake Buds",
        gatt: GattProfile(service: "0000", notify: "0001", write: "0002", nameFragment: "Fake"),
        settings: [
            SettingDescriptor(id: "power", title: "Power", kind: .toggle, section: .sound),
            SettingDescriptor(id: "volume", title: "Volume", kind: .level(0...10, style: .slider), section: .sound),
            SettingDescriptor(id: "codec", title: "Codec", kind: .toggle, section: .smart, appliesWithReconnect: true),
        ]
    )

    var refreshRequests: [Data] {
        Self.settings.indices.map { Self.query($0) } + [Self.batteryQuery]
    }

    func requests(for change: SettingChange, current: DeviceState) -> [Data]? {
        guard let index = Self.settings.firstIndex(of: change.id) else { return nil }
        return [Data([0x01, UInt8(index), Self.byte(change.value)])]
    }

    func confirmingRequest(for setting: SettingID) -> Data? {
        if setting == .battery { return Self.batteryQuery }
        return Self.settings.firstIndex(of: setting).map(Self.query)
    }

    func updates(from packet: Data) -> [DeviceUpdate] {
        let bytes = [UInt8](packet)
        switch bytes.first {
        case 0x02 where bytes.count == 3 && Int(bytes[1]) < Self.settings.count:
            return [.setting(Self.settings[Int(bytes[1])], .level(Int(bytes[2])))]
        case 0x03 where bytes.count == 2:
            return [.battery(Battery(percent: Int(bytes[1]), isCharging: false))]
        default:
            return []
        }
    }

    static let batteryQuery = Data([0x05])

    static func query(_ index: Int) -> Data { Data([0x04, UInt8(index)]) }

    static func reply(_ setting: SettingID, _ value: UInt8) -> Data {
        Data([0x02, UInt8(settings.firstIndex(of: setting)!), value])
    }

    static func set(_ setting: SettingID, _ value: UInt8) -> Data {
        Data([0x01, UInt8(settings.firstIndex(of: setting)!), value])
    }

    static func battery(_ percent: UInt8) -> Data { Data([0x03, percent]) }

    private static func byte(_ value: SettingValue) -> UInt8 {
        switch value {
        case .bool(let isOn): isOn ? 1 : 0
        case .level(let level): UInt8(level)
        case .choice: 9
        }
    }
}

actor FakeByteTransport: DeviceTransport {
    nonisolated let incoming: AsyncStream<Data>
    nonisolated let events: AsyncStream<LinkEvent>
    private let incomingContinuation: AsyncStream<Data>.Continuation
    private let eventsContinuation: AsyncStream<LinkEvent>.Continuation
    private var responses: [Data: [Data]]
    private var remainingConnectFailures: Int
    private let connectFailure: TransportError
    private(set) var sent: [Data] = []
    private(set) var connectCount = 0
    private(set) var disconnectCount = 0
    private(set) var isConnected = false
    private var dropLinkOnSend: Data?
    private let holdsConnect: Bool
    private let heldConnectNumber: Int
    private let identity: DeviceIdentity?
    private(set) var remembered: DeviceIdentity?
    private(set) var rememberedAtFirstConnect: DeviceIdentity?
    private(set) var identityRequested = false
    private let holdsIdentity: Bool
    private var heldIdentity: CheckedContinuation<Void, Never>?
    private var heldConnect: CheckedContinuation<Bool, Never>?

    init(
        responses: [Data: [Data]] = [:],
        connectFailures: Int = 0,
        connectFailure: TransportError = .connectFailed,
        dropLinkOnSend: Data? = nil,
        holdsConnect: Bool = false,
        heldConnectNumber: Int = 1,
        identity: DeviceIdentity? = nil,
        holdsIdentity: Bool = false
    ) {
        self.holdsIdentity = holdsIdentity
        self.heldConnectNumber = heldConnectNumber
        self.identity = identity
        self.dropLinkOnSend = dropLinkOnSend
        self.holdsConnect = holdsConnect
        (incoming, incomingContinuation) = AsyncStream.makeStream()
        (events, eventsContinuation) = AsyncStream.makeStream()
        self.responses = responses
        self.remainingConnectFailures = connectFailures
        self.connectFailure = connectFailure
    }

    func connect() async throws(TransportError) {
        connectCount += 1
        if connectCount == 1 { rememberedAtFirstConnect = remembered }
        if holdsConnect, connectCount == heldConnectNumber {
            let succeeded = await withCheckedContinuation { heldConnect = $0 }
            guard succeeded else { throw connectFailure }
        }
        guard remainingConnectFailures == 0 else {
            remainingConnectFailures -= 1
            throw connectFailure
        }
        isConnected = true
    }

    func disconnect() async {
        heldConnect?.resume(returning: false)
        heldConnect = nil
        disconnectCount += 1
        isConnected = false
    }

    func send(_ data: Data) async throws(TransportError) {
        guard isConnected else { throw .notConnected }
        if data == dropLinkOnSend {
            dropLinkOnSend = nil
            isConnected = false
            eventsContinuation.yield(.disconnected)
            try? await Task.sleep(for: .milliseconds(30))
            throw .notConnected
        }
        sent.append(data)
        for response in responses[data, default: []] {
            incomingContinuation.yield(response)
        }
    }

    func connectedIdentity() async -> DeviceIdentity? {
        identityRequested = true
        if holdsIdentity { await withCheckedContinuation { heldIdentity = $0 } }
        return isConnected ? identity : nil
    }

    func releaseIdentity() {
        heldIdentity?.resume()
        heldIdentity = nil
    }

    func remember(_ identity: DeviceIdentity?) {
        remembered = identity
    }

    func releaseHeldConnect(succeeding: Bool) {
        heldConnect?.resume(returning: succeeding)
        heldConnect = nil
    }

    func failNextConnects(_ count: Int) {
        remainingConnectFailures = count
    }

    func respond(to request: Data, with packets: [Data]) {
        responses[request] = packets
    }

    func emit(_ packet: Data) {
        incomingContinuation.yield(packet)
    }

    func emit(_ event: LinkEvent) {
        if event == .disconnected { isConnected = false }
        eventsContinuation.yield(event)
    }
}
