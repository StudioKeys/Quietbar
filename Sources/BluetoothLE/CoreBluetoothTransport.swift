import CoreBluetooth
import HeadphoneKit
import os

// All mutable state is confined to `queue`, the queue CoreBluetooth delivers every delegate callback on.
public final class CoreBluetoothTransport: NSObject, DeviceTransport, @unchecked Sendable {
    typealias Completion = CheckedContinuation<Result<Void, TransportError>, Never>

    static let logger = Logger(subsystem: "dev.studiokeys.quietbar", category: "CoreBluetoothTransport")

    static let connectTimeout: TimeInterval = 10

    public let incoming: AsyncStream<Data>
    public let events: AsyncStream<LinkEvent>
    let incomingContinuation: AsyncStream<Data>.Continuation
    let profile: GattProfile
    let nameFragment: String
    let eventsContinuation: AsyncStream<LinkEvent>.Continuation
    let queue = DispatchQueue(label: "dev.studiokeys.quietbar.bluetooth")
    var central: CBCentralManager?
    var peripheral: CBPeripheral?
    var writeCharacteristic: CBCharacteristic?
    var pendingConnect: Completion?
    var connectDeadline: DispatchWorkItem?
    var writes: [(data: Data, completion: Completion)] = []
    var isLinkAnnounced = false
    var rememberedID: UUID?

    public init(profile: GattProfile, nameFragment: String) {
        self.profile = profile
        self.nameFragment = nameFragment
        (incoming, incomingContinuation) = AsyncStream.makeStream()
        (events, eventsContinuation) = AsyncStream.makeStream()
        super.init()
        queue.async { self.central = CBCentralManager(delegate: self, queue: self.queue) }
    }

    public func connect() async throws(TransportError) {
        try await withCheckedContinuation { (completion: Completion) in
            queue.async { self.beginConnect(completion) }
        }.get()
    }

    public func disconnect() async {
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            queue.async {
                self.finishConnect(.failure(.connectFailed))
                if let peripheral = self.peripheral {
                    self.central?.cancelPeripheralConnection(peripheral)
                }
                done.resume()
            }
        }
    }

    public func send(_ data: Data) async throws(TransportError) {
        try await withCheckedContinuation { (completion: Completion) in
            queue.async { self.enqueueWrite(data, completion) }
        }.get()
    }

    public func connectedIdentity() async -> DeviceIdentity? {
        await withCheckedContinuation { (done: CheckedContinuation<DeviceIdentity?, Never>) in
            queue.async {
                guard let peripheral = self.peripheral, peripheral.state == .connected else {
                    done.resume(returning: nil)
                    return
                }
                let name = peripheral.name ?? self.nameFragment
                done.resume(
                    returning: DeviceIdentity(name: name, linkID: peripheral.identifier.uuidString, classicAddress: nil)
                )
            }
        }
    }

    public func remember(_ identity: DeviceIdentity?) async {
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            queue.async {
                self.rememberedID = identity.flatMap { UUID(uuidString: $0.linkID) }
                done.resume()
            }
        }
    }

    private func beginConnect(_ completion: Completion) {
        guard pendingConnect == nil else {
            completion.resume(returning: .failure(.connectFailed))
            return
        }
        pendingConnect = completion
        armConnectDeadline()
        proceedIfPoweredOn()
    }

    func proceedIfPoweredOn() {
        guard pendingConnect != nil, let central else { return }
        if let issue = central.state.bluetoothIssue {
            finishConnect(.failure(.bluetoothUnavailable(issue)))
            return
        }
        guard central.state == .poweredOn else { return }
        let connected = central.retrieveConnectedPeripherals(withServices: [serviceUUID])
        if let known = connected.first(where: { $0.identifier == rememberedID }) ?? connected.first {
            attach(known)
        } else {
            central.scanForPeripherals(withServices: nil)
        }
    }

    func attach(_ found: CBPeripheral) {
        central?.stopScan()
        peripheral = found
        found.delegate = self
        central?.connect(found)
    }

    private func armConnectDeadline() {
        let deadline = DispatchWorkItem { [weak self] in
            guard let self, self.pendingConnect != nil else { return }
            self.central?.stopScan()
            self.finishConnect(.failure(self.peripheral == nil ? .notFound : .connectFailed))
            if let peripheral = self.peripheral {
                self.central?.cancelPeripheralConnection(peripheral)
            }
        }
        connectDeadline = deadline
        queue.asyncAfter(deadline: .now() + Self.connectTimeout, execute: deadline)
    }

    func finishConnect(_ result: Result<Void, TransportError>) {
        connectDeadline?.cancel()
        connectDeadline = nil
        guard let pending = pendingConnect else { return }
        pendingConnect = nil
        pending.resume(returning: result)
    }

    private func enqueueWrite(_ data: Data, _ completion: Completion) {
        guard peripheral?.state == .connected, writeCharacteristic != nil else {
            completion.resume(returning: .failure(.notConnected))
            return
        }
        writes.append((data, completion))
        if writes.count == 1 { startNextWrite() }
    }

    func startNextWrite() {
        guard let next = writes.first, let peripheral, let writeCharacteristic else { return }
        peripheral.writeValue(next.data, for: writeCharacteristic, type: .withResponse)
    }

    func completeWrite(_ result: Result<Void, TransportError>) {
        guard !writes.isEmpty else { return }
        writes.removeFirst().completion.resume(returning: result)
        startNextWrite()
    }

    func failAllWrites() {
        let failed = writes
        writes = []
        for write in failed {
            write.completion.resume(returning: .failure(.notConnected))
        }
    }
}

extension CBManagerState {
    var bluetoothIssue: BluetoothIssue? {
        switch self {
        case .poweredOff: .poweredOff
        case .unauthorized: .unauthorized
        case .unsupported: .unsupported
        default: nil
        }
    }
}

extension CoreBluetoothTransport {
    var serviceUUID: CBUUID { CBUUID(string: profile.service) }
    var notifyUUID: CBUUID { CBUUID(string: profile.notify) }
    var writeUUID: CBUUID { CBUUID(string: profile.write) }
}
