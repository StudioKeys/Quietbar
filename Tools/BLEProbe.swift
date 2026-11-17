import CoreBluetooth
import Foundation

let serviceUUID = CBUUID(string: "65786365-6c70-6f69-6e74-2e636f6d0000")
let notifyUUID = CBUUID(string: "65786365-6c70-6f69-6e74-2e636f6d0001")
let writeUUID = CBUUID(string: "65786365-6c70-6f69-6e74-2e636f6d0002")
let deviceNameFragment = "770NC"
let scanTimeoutSeconds: TimeInterval = 20
let replyTimeoutSeconds: TimeInterval = 3

let readOnlyQueries: [(label: String, bytes: [UInt8])] = [
    ("noise mode", [0xAA, 0x91, 0x01, 0x11]),
    ("battery", [0xAA, 0x25, 0x01, 0x00]),
    ("spatial sound", [0xAA, 0x9D, 0x01, 0x01]),
    ("low volume EQ", [0xAA, 0x9E, 0x01, 0x01]),
    ("EQ preset", [0xAA, 0xA2, 0x02, 0x01, 0xFF]),
    ("advanced ANC", [0xAA, 0x91, 0x01, 0x21]),
    ("L/R balance", [0xAA, 0xA8, 0x01, 0x01]),
]

func hex(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined(separator: " ")
}

func describe(_ b: [UInt8]) -> String {
    guard b.count >= 3, b[0] == 0xAA else { return "unrecognised frame" }
    switch (b[1], b.count) {
    case (0x91, 10...):
        let modes = ["ANC": b[5], "Ambient Aware": b[7], "Talk-Thru": b[9]]
        return "noise mode: " + (modes.first { $0.value == 1 }?.key ?? "off")
    case (0x25, 8...):
        return "battery: \(b[6])% charging=\(b[4] != 0)"
    case (0x9D, 6...):
        let modes: [UInt8: String] = [1: "Music", 2: "Movie", 3: "Game"]
        return "spatial: \(b[4] == 1 ? "on" : "off") mode=\(modes[b[5]] ?? "?")"
    case (0x9E, 5...):
        return "low volume EQ: \(b[4] == 1 ? "on" : "off")"
    case (0xA2, 6...):
        let presets: [UInt8: String] = [1: "Jazz", 2: "Vocal", 3: "Bass", 6: "Club", 7: "Studio", 9: "Extreme Bass"]
        return "EQ preset: \(presets[b[5]] ?? String(format: "custom 0x%02x", b[5]))"
    default:
        return "unhandled cmd 0x" + String(format: "%02x", b[1])
    }
}

final class Probe: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var pending = readOnlyQueries

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            print("Bluetooth state: \(central.state.rawValue) (need poweredOn=5; check permission)")
            if central.state == .unauthorized || central.state == .unsupported { exit(1) }
            return
        }
        if let known = central.retrieveConnectedPeripherals(withServices: [serviceUUID]).first {
            print("Already connected over LE: \(known.name ?? "?")")
            connect(known)
            return
        }
        print("Scanning for *\(deviceNameFragment)* …")
        central.scanForPeripherals(withServices: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + scanTimeoutSeconds) { [weak self] in
            guard self?.peripheral == nil else { return }
            print("No device found in \(Int(scanTimeoutSeconds))s. Close the JBL app on the phone and retry.")
            exit(2)
        }
    }

    func centralManager(
        _ central: CBCentralManager, didDiscover p: CBPeripheral,
        advertisementData: [String: Any], rssi: NSNumber
    ) {
        let name = p.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""
        guard name.contains(deviceNameFragment), peripheral == nil else { return }
        print("Found \(name) rssi=\(rssi)")
        central.stopScan()
        connect(p)
    }

    private func connect(_ p: CBPeripheral) {
        peripheral = p
        p.delegate = self
        central.connect(p)
    }

    func centralManager(_ central: CBCentralManager, didConnect p: CBPeripheral) {
        print("Connected, discovering service")
        p.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        print("Connect failed: \(error?.localizedDescription ?? "unknown")")
        exit(3)
    }

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = p.services?.first(where: { $0.uuid == serviceUUID }) else {
            print("Control service not found: \(error?.localizedDescription ?? "absent")")
            exit(4)
        }
        p.discoverCharacteristics([notifyUUID, writeUUID], for: service)
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let chars = service.characteristics ?? []
        guard let notify = chars.first(where: { $0.uuid == notifyUUID }),
            let write = chars.first(where: { $0.uuid == writeUUID })
        else {
            print("Characteristics missing: \(error?.localizedDescription ?? "absent")")
            exit(5)
        }
        writeChar = write
        p.setNotifyValue(true, for: notify)
    }

    func peripheral(_ p: CBPeripheral, didUpdateNotificationStateFor c: CBCharacteristic, error: Error?) {
        if let error {
            print("Enable notify failed: \(error.localizedDescription)")
            exit(6)
        }
        sendNext()
    }

    private func sendNext() {
        guard let p = peripheral, let write = writeChar else { return }
        guard !pending.isEmpty else {
            DispatchQueue.main.asyncAfter(deadline: .now() + replyTimeoutSeconds) { exit(0) }
            return
        }
        let query = pending.removeFirst()
        print("-> \(query.label): \(hex(Data(query.bytes)))")
        p.writeValue(Data(query.bytes), for: write, type: .withResponse)
    }

    func peripheral(_ p: CBPeripheral, didWriteValueFor c: CBCharacteristic, error: Error?) {
        if let error { print("   write error: \(error.localizedDescription)") }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.sendNext() }
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        guard let value = c.value else { return }
        print("<- \(hex(value))  [\(describe([UInt8](value)))]")
    }
}

let probe = Probe()
RunLoop.main.run()
