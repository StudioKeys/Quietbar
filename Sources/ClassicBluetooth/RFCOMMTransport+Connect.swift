import Foundation
import HeadphoneKit
import IOBluetooth

extension RFCOMMTransport: IOBluetoothRFCOMMChannelDelegate {
    func beginConnect(_ completion: Completion) {
        guard pendingConnect == nil else {
            completion.resume(returning: .failure(.connectFailed))
            return
        }
        if channel?.isOpen() == true {
            completion.resume(returning: .success(()))
            return
        }
        guard IOBluetoothHostController.default()?.powerState == kBluetoothHCIPowerStateON else {
            completion.resume(returning: .failure(.bluetoothUnavailable(.poweredOff)))
            return
        }
        guard let found = findDevice(), found.isConnected() else {
            completion.resume(returning: .failure(.notFound))
            return
        }
        pendingConnect = completion
        device = found
        armConnectDeadline()
        if found.getServiceRecord(for: serviceUUID) == nil {
            found.performSDPQuery(self, uuids: [serviceUUID])
        } else {
            openChannel(on: found)
        }
    }

    @objc func sdpQueryComplete(_ device: IOBluetoothDevice, status: IOReturn) {
        guard pendingConnect != nil, device == self.device else { return }
        openChannel(on: device)
    }

    private func findDevice() -> IOBluetoothDevice? {
        let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        if let address = rememberedAddress, let known = paired.first(where: { $0.addressString == address }) {
            return known
        }
        return paired.first { $0.name?.localizedCaseInsensitiveContains(nameFragment) == true }
    }

    private func openChannel(on device: IOBluetoothDevice) {
        var channelID: BluetoothRFCOMMChannelID = 0
        guard let record = device.getServiceRecord(for: serviceUUID),
            record.getRFCOMMChannelID(&channelID) == kIOReturnSuccess
        else {
            Self.logger.notice("Control service not found on \(device.name ?? "device", privacy: .public)")
            finishConnect(.failure(.connectFailed))
            return
        }
        var opened: IOBluetoothRFCOMMChannel?
        let status = device.openRFCOMMChannelAsync(&opened, withChannelID: channelID, delegate: self)
        guard status == kIOReturnSuccess else {
            finishConnect(.failure(.connectFailed))
            return
        }
        channel = opened
    }

    private func armConnectDeadline() {
        let deadline = DispatchWorkItem { [weak self] in
            guard let self, self.pendingConnect != nil else { return }
            self.channel?.setDelegate(nil)
            self.channel?.close()
            self.channel = nil
            self.finishConnect(.failure(.connectFailed))
        }
        connectDeadline = deadline
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.connectTimeout, execute: deadline)
    }

    func finishConnect(_ result: Result<Void, TransportError>) {
        connectDeadline?.cancel()
        connectDeadline = nil
        guard let pending = pendingConnect else { return }
        pendingConnect = nil
        pending.resume(returning: result)
    }

    public func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        guard rfcommChannel == channel else { return }
        guard error == kIOReturnSuccess else {
            Self.logger.notice("RFCOMM open failed: \(error, privacy: .public)")
            channel = nil
            finishConnect(.failure(.connectFailed))
            return
        }
        channel = rfcommChannel
        isLinkAnnounced = true
        eventsContinuation.yield(.connected)
        finishConnect(.success(()))
    }

    public func rfcommChannelData(
        _ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int
    ) {
        guard rfcommChannel == channel else { return }
        incomingContinuation.yield(Data(bytes: dataPointer, count: dataLength))
    }

    public func rfcommChannelWriteComplete(
        _ rfcommChannel: IOBluetoothRFCOMMChannel!, refcon: UnsafeMutableRawPointer!, status error: IOReturn
    ) {
        guard rfcommChannel == channel else { return }
        completeWrite(error == kIOReturnSuccess ? .success(()) : .failure(.writeFailed))
    }

    public func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        guard rfcommChannel == channel else { return }
        channel = nil
        failPendingWrites()
        finishConnect(.failure(.connectFailed))
        guard isLinkAnnounced else { return }
        isLinkAnnounced = false
        Self.logger.info("RFCOMM channel closed")
        eventsContinuation.yield(.disconnected)
    }
}
