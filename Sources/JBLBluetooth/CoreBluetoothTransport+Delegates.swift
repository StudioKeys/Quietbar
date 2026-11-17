import CoreBluetooth
import JBLProtocol

extension CoreBluetoothTransport: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if let issue = central.state.bluetoothIssue {
            failAllWrites()
            eventsContinuation.yield(.bluetoothUnavailable(issue))
        } else if central.state == .poweredOn {
            eventsContinuation.yield(.bluetoothReady)
        }
        proceedIfPoweredOn()
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover discovered: CBPeripheral,
        advertisementData: [String: Any],
        rssi: NSNumber
    ) {
        let name = discovered.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""
        guard pendingConnect != nil, peripheral == nil, name.contains(GattIdentifiers.deviceNameFragment) else {
            return
        }
        Self.logger.info("Found \(name, privacy: .public)")
        attach(discovered)
    }

    public func centralManager(_ central: CBCentralManager, didConnect connected: CBPeripheral) {
        connected.discoverServices([GattIdentifiers.service])
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect failed: CBPeripheral, error: Error?) {
        Self.logger.error("Connect failed: \(error?.localizedDescription ?? "unknown", privacy: .public)")
        peripheral = nil
        finishConnect(.failure(.connectFailed))
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral disconnected: CBPeripheral,
        error: Error?
    ) {
        Self.logger.notice("Disconnected: \(error?.localizedDescription ?? "requested", privacy: .public)")
        writeCharacteristic = nil
        peripheral = nil
        failAllWrites()
        finishConnect(.failure(.connectFailed))
        eventsContinuation.yield(.disconnected)
    }
}

extension CoreBluetoothTransport: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == GattIdentifiers.service }) else {
            abandon(peripheral, reason: "control service missing")
            return
        }
        peripheral.discoverCharacteristics([GattIdentifiers.notify, GattIdentifiers.write], for: service)
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?)
    {
        let characteristics = service.characteristics ?? []
        guard let notify = characteristics.first(where: { $0.uuid == GattIdentifiers.notify }),
            let write = characteristics.first(where: { $0.uuid == GattIdentifiers.write })
        else {
            abandon(peripheral, reason: "control characteristics missing")
            return
        }
        writeCharacteristic = write
        peripheral.setNotifyValue(true, for: notify)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil, characteristic.isNotifying else {
            abandon(peripheral, reason: "notifications refused")
            return
        }
        finishConnect(.success(()))
        eventsContinuation.yield(.connected)
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?)
    {
        completeWrite(error == nil ? .success(()) : .failure(.writeFailed))
    }

    public func peripheral(
        _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?
    ) {
        guard characteristic.uuid == GattIdentifiers.notify, let value = characteristic.value else { return }
        do {
            incomingContinuation.yield(try Frame.decode(value))
        } catch {
            Self.logger.debug("Ignored malformed frame: \(String(describing: error), privacy: .public)")
        }
    }

    private func abandon(_ peripheral: CBPeripheral, reason: String) {
        Self.logger.error("Abandoning connection: \(reason, privacy: .public)")
        finishConnect(.failure(.connectFailed))
        central?.cancelPeripheralConnection(peripheral)
    }
}
