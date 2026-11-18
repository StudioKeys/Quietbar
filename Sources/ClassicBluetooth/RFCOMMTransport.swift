import Foundation
import HeadphoneKit
import IOBluetooth
import os

// IOBluetooth calls its delegates on the main run loop, so all mutable state below is touched only on main.
public final class RFCOMMTransport: NSObject, DeviceTransport, @unchecked Sendable {
    typealias Completion = CheckedContinuation<Result<Void, TransportError>, Never>

    static let logger = Logger(subsystem: "dev.studiokeys.quietbar", category: "RFCOMMTransport")
    static let connectTimeout: TimeInterval = 10

    public let incoming: AsyncStream<Data>
    public let events: AsyncStream<LinkEvent>
    let incomingContinuation: AsyncStream<Data>.Continuation
    let eventsContinuation: AsyncStream<LinkEvent>.Continuation
    let serviceUUID: IOBluetoothSDPUUID
    let nameFragment: String
    var device: IOBluetoothDevice?
    var channel: IOBluetoothRFCOMMChannel?
    var pendingConnect: Completion?
    var connectDeadline: DispatchWorkItem?
    var rememberedAddress: String?
    var isLinkAnnounced = false
    var pendingWrites: [Completion] = []

    public init(serviceUUID: String, nameFragment: String) {
        var uuid = (UUID(uuidString: serviceUUID) ?? UUID()).uuid
        self.serviceUUID = withUnsafeBytes(of: &uuid) { IOBluetoothSDPUUID(bytes: $0.baseAddress, length: $0.count) }
        self.nameFragment = nameFragment
        (incoming, incomingContinuation) = AsyncStream.makeStream()
        (events, eventsContinuation) = AsyncStream.makeStream()
        super.init()
    }

    public func connect() async throws(TransportError) {
        try await withCheckedContinuation { (completion: Completion) in
            DispatchQueue.main.async { self.beginConnect(completion) }
        }.get()
    }

    public func disconnect() async {
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                self.finishConnect(.failure(.connectFailed))
                self.isLinkAnnounced = false
                self.failPendingWrites()
                self.channel?.setDelegate(nil)
                self.channel?.close()
                self.channel = nil
                done.resume()
            }
        }
    }

    public func send(_ data: Data) async throws(TransportError) {
        try await withCheckedContinuation { (completion: Completion) in
            DispatchQueue.main.async { self.write(data, completion) }
        }.get()
    }

    public func connectedIdentity() async -> DeviceIdentity? {
        await withCheckedContinuation { (done: CheckedContinuation<DeviceIdentity?, Never>) in
            DispatchQueue.main.async {
                guard self.channel?.isOpen() == true, let device = self.device, let address = device.addressString
                else {
                    done.resume(returning: nil)
                    return
                }
                let name = device.name ?? self.nameFragment
                done.resume(
                    returning: DeviceIdentity(name: name, linkID: address, classicAddress: address, classicName: name))
            }
        }
    }

    public func remember(_ identity: DeviceIdentity?) async {
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                self.rememberedAddress = identity?.classicAddress ?? identity?.linkID
                done.resume()
            }
        }
    }

    private func write(_ data: Data, _ completion: Completion) {
        guard let channel, channel.isOpen() else {
            completion.resume(returning: .failure(.notConnected))
            return
        }
        var bytes = [UInt8](data)
        guard channel.writeAsync(&bytes, length: UInt16(bytes.count), refcon: nil) == kIOReturnSuccess else {
            completion.resume(returning: .failure(.writeFailed))
            return
        }
        pendingWrites.append(completion)
    }

    func completeWrite(_ result: Result<Void, TransportError>) {
        guard !pendingWrites.isEmpty else { return }
        pendingWrites.removeFirst().resume(returning: result)
    }

    func failPendingWrites() {
        let waiting = pendingWrites
        pendingWrites = []
        for completion in waiting { completion.resume(returning: .failure(.notConnected)) }
    }
}
