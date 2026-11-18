import Foundation
import HeadphoneKit
import IOBluetooth
import os

// IOBluetooth calls its delegates on the main run loop, so all mutable state below is touched only on main.
public final class RFCOMMTransport: NSObject, DeviceTransport, @unchecked Sendable {
    typealias Completion = CheckedContinuation<Result<Void, TransportError>, Never>

    static let logger = Logger.quietbar("RFCOMMTransport")
    static let connectTimeout: TimeInterval = 10
    static let writeTimeout: TimeInterval = 3

    struct PendingWrite {
        let id: UInt
        let completion: Completion
        let deadline: DispatchWorkItem
    }

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
    var pendingWrites: [PendingWrite] = []
    var nextWriteID: UInt = 1

    public init(serviceUUID: UUID, nameFragment: String) {
        var uuid = serviceUUID.uuid
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
        let id = nextWriteID
        nextWriteID += 1
        var bytes = [UInt8](data)
        let refcon = UnsafeMutableRawPointer(bitPattern: id)
        guard channel.writeAsync(&bytes, length: UInt16(bytes.count), refcon: refcon) == kIOReturnSuccess else {
            completion.resume(returning: .failure(.writeFailed))
            return
        }
        let deadline = DispatchWorkItem { [weak self] in self?.writeTimedOut(id) }
        pendingWrites.append(PendingWrite(id: id, completion: completion, deadline: deadline))
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.writeTimeout, execute: deadline)
    }

    func completeWrite(id: UInt, _ result: Result<Void, TransportError>) {
        guard let index = pendingWrites.firstIndex(where: { $0.id == id }) else { return }
        let write = pendingWrites.remove(at: index)
        write.deadline.cancel()
        write.completion.resume(returning: result)
    }

    func failPendingWrites(_ error: TransportError = .notConnected) {
        let waiting = pendingWrites
        pendingWrites = []
        for write in waiting {
            write.deadline.cancel()
            write.completion.resume(returning: .failure(error))
        }
    }

    private func writeTimedOut(_ id: UInt) {
        guard pendingWrites.contains(where: { $0.id == id }) else { return }
        Self.logger.notice("RFCOMM write stalled; closing the channel")
        failPendingWrites(.writeFailed)
        channel?.setDelegate(nil)
        channel?.close()
        channel = nil
        guard isLinkAnnounced else { return }
        isLinkAnnounced = false
        eventsContinuation.yield(.disconnected)
    }
}
