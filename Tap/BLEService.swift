import Foundation
import CoreBluetooth
import UIKit

class BLEService: NSObject, ObservableObject {
    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    private var connectedPeripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    private var pendingPaymentRequest: String?
    private var shouldStartScanningWhenReady = false
    private let hapticEngine = UIImpactFeedbackGenerator(style: .heavy)
    private var lastHapticTime: TimeInterval = 0
    private let hapticThrottleInterval: TimeInterval = 0.3 // Reduced from 0.5 to allow more frequent haptics
    
    // Custom service UUID for our app - using a 16-bit UUID
    private let serviceUUID = CBUUID(string: "FFE0")
    private let characteristicUUID = CBUUID(string: "FFE1")
    
    @Published var isScanning = false
    @Published var isAdvertising = false
    @Published var receivedMessage: String?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var isInRange = false // New property to track if device is in tap range
    
    // RSSI thresholds and filtering
    private let rssiThresholdForConnection: Int = -30  // Less strict, allows slightly more distance
    private let rssiThresholdForHaptic: Int = -35     // Start haptic feedback at ~5cm
    private var lastValidRSSI: Int = -100             // Store last valid RSSI
    private let rssiSmoothingFactor: Double = 0.3     // More responsive smoothing
    private let invalidRSSI: Int = 127                // Special value indicating invalid RSSI
    private var consecutiveValidReadings: Int = 0     // Count of consistent readings
    private let requiredConsistentReadings: Int = 2   // Reduced from 3 to 2 for faster connection
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
    }
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        shouldStartScanningWhenReady = true
        hapticEngine.prepare() // Prepare haptic engine
    }
    
    func startScanning() {
        if centralManager.state == .poweredOn {
            print("Starting scan immediately")
            isScanning = true
            connectionState = .disconnected
            
            // Modified: Simplified scanning options to avoid warnings
            let options: [String: Any] = [
                CBCentralManagerScanOptionAllowDuplicatesKey: true
            ]
            
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: options)
        } else {
            print("Will start scanning when Bluetooth is ready")
            shouldStartScanningWhenReady = true
        }
    }
    
    func stopScanning() {
        isScanning = false
        centralManager.stopScan()
    }
    
    func startAdvertising() {
        guard peripheralManager.state == .poweredOn else { return }
        isAdvertising = true
        connectionState = .disconnected
        
        // Create the service if not already created
        setupService()
        
        // Modified: Removed the CBAdvertisementDataTxPowerLevelKey to avoid warnings
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "Tap Payment"
        ]
        peripheralManager.startAdvertising(advertisementData)
    }
    
    func stopAdvertising() {
        isAdvertising = false
        peripheralManager.stopAdvertising()
        pendingPaymentRequest = nil
    }
    
    func broadcastPaymentRequest(amount: Double, walletAddress: String, note: String = "") {
        // First ensure we're in a clean state
        stopAdvertising()
        disconnect()
        characteristic = nil
        peripheralCharacteristic = nil
        receivedMessage = nil
        connectionState = .disconnected
        isInRange = false
        
        // Create payment request message
        let message = "PAYMENT_REQUEST:\(amount):\(walletAddress):\(note)"
        pendingPaymentRequest = message
        
        // Start fresh advertising
        startAdvertising()
    }
    
    func sendPaymentResponse(approved: Bool, transactionDetails: [String: String] = [:]) {
        // Create a more detailed payment response message
        var message = "PAYMENT_RESPONSE:\(approved ? "APPROVED" : "DECLINED")"
        
        // Add transaction details if available
        if approved, 
           let txHash = transactionDetails["hash"],
           let amount = transactionDetails["amount"],
           let sender = transactionDetails["sender"],
           let recipient = transactionDetails["recipient"] {
            // Format: PAYMENT_RESPONSE:APPROVED:HASH:AMOUNT:SENDER:RECIPIENT:NOTE
            message += ":\(txHash):\(amount):\(sender):\(recipient)"
            
            // Add note if available
            if let note = transactionDetails["note"] {
                message += ":\(note)"
            }
        }
        
        sendMessage(message)
        
        // Stop scanning immediately to prevent receiving more advertisements
        stopScanning()
        
        // Wait briefly to ensure the message is sent before cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Full cleanup
            self.receivedMessage = nil
            self.characteristic = nil
            self.peripheralCharacteristic = nil
            self.pendingPaymentRequest = nil
            self.isInRange = false
            
            print("Payment response sent, cleaning up...")
            self.disconnect()  // This will handle stopping scan/advertising
            self.connectionState = .disconnected
            
            // Only restart scanning after ensuring complete disconnection
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                print("Restarting scan for new payment requests...")
                self.startScanning()
            }
        }
    }
    
    private func connect(peripheral: CBPeripheral) {
        // Only connect if we're not already connected
        guard connectionState == .disconnected else { return }
        
        print("Attempting to connect to peripheral: \(peripheral.name ?? "Unknown")")
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
        stopAdvertising()
        stopScanning()
        pendingPaymentRequest = nil
    }
    
    private func sendMessage(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        
        if let characteristic = characteristic {
            // If we have a characteristic, we're the central (customer)
            connectedPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
        } else if let peripheralChar = peripheralCharacteristic {
            // If we don't have a characteristic, we're the peripheral (merchant)
            // Update value and notify subscribers
            peripheralManager.updateValue(data, for: peripheralChar, onSubscribedCentrals: nil)
        }
    }
    
    private var peripheralCharacteristic: CBMutableCharacteristic?
    
    private func setupService() {
        // Create the service
        let service = CBMutableService(type: serviceUUID, primary: true)
        
        // Create the characteristic
        peripheralCharacteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.write, .notify, .read],
            value: nil,
            permissions: [.writeable, .readable]
        )
        
        // Add the characteristic to the service
        if let peripheralChar = peripheralCharacteristic {
            service.characteristics = [peripheralChar]
            
            // Add the service to the peripheral manager
            peripheralManager.removeAllServices()
            peripheralManager.add(service)
            
            // If we have a pending payment request, send it
            if let message = pendingPaymentRequest,
               let data = message.data(using: .utf8) {
                peripheralManager.updateValue(data, for: peripheralChar, onSubscribedCentrals: nil)
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
            if shouldStartScanningWhenReady {
                print("Starting delayed scan")
                startScanning()
            }
        case .poweredOff:
            print("Bluetooth is powered off")
            connectionState = .disconnected
            isScanning = false
        case .resetting:
            print("Bluetooth is resetting")
            connectionState = .disconnected
            isScanning = false
        case .unauthorized:
            print("Bluetooth is unauthorized")
            connectionState = .disconnected
            isScanning = false
        case .unknown:
            print("Bluetooth state is unknown")
            connectionState = .disconnected
            isScanning = false
        case .unsupported:
            print("Bluetooth is not supported")
            connectionState = .disconnected
            isScanning = false
        @unknown default:
            print("Unknown Bluetooth state")
            connectionState = .disconnected
            isScanning = false
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let rawRSSIValue = RSSI.intValue
        
        // Filter out invalid RSSI readings
        guard rawRSSIValue != invalidRSSI else {
            print("Ignoring invalid RSSI reading")
            return
        }
        
        // Don't process if we already have a received message (prevents reconnection after response)
        if receivedMessage?.starts(with: "PAYMENT_RESPONSE:") == true {
            print("Payment already processed, ignoring discovery")
            return
        }
        
        // Apply exponential smoothing to RSSI
        let smoothedRSSI = Int(Double(lastValidRSSI) * (1.0 - rssiSmoothingFactor) + Double(rawRSSIValue) * rssiSmoothingFactor)
        
        // Check if the reading is consistent with the last one
        if abs(smoothedRSSI - lastValidRSSI) <= 5 { // Increased tolerance from 3 to 5
            consecutiveValidReadings += 1
        } else {
            consecutiveValidReadings = 0
        }
        
        lastValidRSSI = smoothedRSSI
        
        print("Raw RSSI: \(rawRSSIValue) dBm, Smoothed RSSI: \(smoothedRSSI) dBm, Consistent Readings: \(consecutiveValidReadings)")
        print("Connection threshold: \(rssiThresholdForConnection) dBm")
        
        // Update isInRange and provide haptic feedback when getting close
        let nowTime = Date().timeIntervalSince1970
        let shouldTriggerHaptic = (nowTime - lastHapticTime) > hapticThrottleInterval
        
        if smoothedRSSI < rssiThresholdForHaptic {
            print("Too far for haptic feedback: \(smoothedRSSI) < \(rssiThresholdForHaptic)")
            DispatchQueue.main.async {
                self.isInRange = false
            }
        } else {
            print("In range for haptic: \(smoothedRSSI) >= \(rssiThresholdForHaptic)")
            if !isInRange && shouldTriggerHaptic {
                DispatchQueue.main.async {
                    self.isInRange = true
                    self.hapticEngine.impactOccurred(intensity: 0.8)
                    self.lastHapticTime = nowTime
                    print("Triggered haptic feedback")
                }
            }
        }
        
        // Only connect if we have consistent readings and are close enough
        if smoothedRSSI >= rssiThresholdForConnection && 
           consecutiveValidReadings >= requiredConsistentReadings && 
           connectionState == .disconnected {
            print("✅ Device in range with consistent readings, connecting... Smoothed RSSI: \(smoothedRSSI)")
            connect(peripheral: peripheral)
            DispatchQueue.main.async {
                self.hapticEngine.impactOccurred(intensity: 1.0)
            }
        } else {
            if connectionState != .disconnected {
                print("❌ Not connecting: Already in state: \(connectionState)")
            } else if consecutiveValidReadings < requiredConsistentReadings {
                print("❌ Not connecting: Need more consistent readings (\(consecutiveValidReadings)/\(requiredConsistentReadings))")
            } else {
                print("❌ Not connecting: Smoothed RSSI \(smoothedRSSI) < threshold \(rssiThresholdForConnection)")
            }
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
        
        // If we're still scanning, look for other devices
        if isScanning {
            startScanning()
        }
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
                // Also read the current value
                peripheral.readValue(for: characteristic)
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
            if isAdvertising {
                setupService()
            }
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
                
                // Handle both approved and declined responses
                if message.starts(with: "PAYMENT_RESPONSE:") {
                    _ = message.contains("APPROVED")
                    
                    // Update UI immediately with the response
                    DispatchQueue.main.async {
                        self.receivedMessage = message
                    }
                    
                    // Respond to the request
                    peripheral.respond(to: request, withResult: .success)
                    
                    // Cleanup after ensuring message is delivered
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // Stop advertising first
                        self.stopAdvertising()
                        
                        // Then clean up everything else
                        self.pendingPaymentRequest = nil
                        self.characteristic = nil
                        self.peripheralCharacteristic = nil
                        self.connectionState = .disconnected
                        self.isInRange = false
                        
                        // Clear the received message after showing it briefly
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.receivedMessage = nil
                        }
                    }
                    return // Exit early after handling payment response
                }
                
                // For other messages
                DispatchQueue.main.async {
                    self.receivedMessage = message
                }
                peripheral.respond(to: request, withResult: .success)
            }
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("Central subscribed to characteristic")
        // Only send the payment request if we haven't sent it to this central yet
        if let message = pendingPaymentRequest,
           let data = message.data(using: .utf8),
           let peripheralChar = peripheralCharacteristic,
           receivedMessage == nil { // Only send if we haven't received a response
            print("Sending payment request to new subscriber")
            peripheralManager.updateValue(data, for: peripheralChar, onSubscribedCentrals: [central])
        }
    }
} 
