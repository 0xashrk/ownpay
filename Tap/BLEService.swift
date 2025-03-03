import Foundation
import CoreBluetooth
import UIKit

class BLEService: NSObject, ObservableObject {
    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    private var connectedPeripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    
    // Custom service UUID for our app - using a 16-bit UUID
    private let serviceUUID = CBUUID(string: "FFE0")
    private let characteristicUUID = CBUUID(string: "FFE1")
    
    @Published var isScanning = false
    @Published var isAdvertising = false
    @Published var receivedMessage: String?
    @Published var connectionState: ConnectionState = .disconnected
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
    }
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        isScanning = true
        connectionState = .disconnected
        // Only scan for devices with our custom service UUID
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
    
    func stopScanning() {
        isScanning = false
        centralManager.stopScan()
    }
    
    func startAdvertising() {
        guard peripheralManager.state == .poweredOn else { return }
        isAdvertising = true
        connectionState = .disconnected
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "Tap Payment"
        ]
        peripheralManager.startAdvertising(advertisementData)
    }
    
    func stopAdvertising() {
        isAdvertising = false
        peripheralManager.stopAdvertising()
    }
    
    func broadcastPaymentRequest(amount: Double, walletAddress: String) {
        // Start advertising to make this device discoverable
        startAdvertising()
        
        // Create payment request message
        let message = "PAYMENT_REQUEST:\(amount):\(walletAddress)"
        sendMessage(message)
    }
    
    private func connect(peripheral: CBPeripheral) {
        // Only connect if we're not already connected
        guard connectionState == .disconnected else { return }
        
        connectionState = .connecting
        connectedPeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
            connectedPeripheral = nil
            characteristic = nil
            connectionState = .disconnected
        }
    }
    
    func sendMessage(_ message: String) {
        guard let characteristic = characteristic,
              let data = message.data(using: .utf8) else { return }
        
        connectedPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
            // Automatically start scanning when powered on
            startScanning()
        case .poweredOff:
            print("Bluetooth is powered off")
            connectionState = .disconnected
        case .resetting:
            print("Bluetooth is resetting")
            connectionState = .disconnected
        case .unauthorized:
            print("Bluetooth is unauthorized")
            connectionState = .disconnected
        case .unknown:
            print("Bluetooth state is unknown")
            connectionState = .disconnected
        case .unsupported:
            print("Bluetooth is not supported")
            connectionState = .disconnected
        @unknown default:
            print("Unknown Bluetooth state")
            connectionState = .disconnected
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("Discovered Tap device")
        // Only connect if we're not already connected
        if connectionState == .disconnected {
            connect(peripheral: peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to Tap device")
        connectionState = .connected
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from Tap device")
        connectionState = .disconnected
        connectedPeripheral = nil
        characteristic = nil
    }
}

// MARK: - CBPeripheralDelegate
extension BLEService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == characteristicUUID {
                self.characteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                break
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value,
              let message = String(data: data, encoding: .utf8) else { return }
        
        print("Received message: \(message)")
        DispatchQueue.main.async {
            self.receivedMessage = message
        }
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BLEService: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("Peripheral manager is powered on")
            setupService()
        case .poweredOff:
            print("Peripheral manager is powered off")
            connectionState = .disconnected
        case .resetting:
            print("Peripheral manager is resetting")
            connectionState = .disconnected
        case .unauthorized:
            print("Peripheral manager is unauthorized")
            connectionState = .disconnected
        case .unknown:
            print("Peripheral manager state is unknown")
            connectionState = .disconnected
        case .unsupported:
            print("Peripheral manager is not supported")
            connectionState = .disconnected
        @unknown default:
            print("Unknown peripheral manager state")
            connectionState = .disconnected
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if let data = request.value,
               let message = String(data: data, encoding: .utf8) {
                print("Received write request with message: \(message)")
                DispatchQueue.main.async {
                    self.receivedMessage = message
                }
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }
    
    private func setupService() {
        // Create the service
        let service = CBMutableService(type: serviceUUID, primary: true)
        
        // Create the characteristic
        let characteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.write, .notify],
            value: nil,
            permissions: [.writeable]
        )
        
        // Add the characteristic to the service
        service.characteristics = [characteristic]
        
        // Add the service to the peripheral manager
        peripheralManager.add(service)
    }
} 