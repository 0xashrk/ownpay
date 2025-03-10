import SwiftUI
import CoreBluetooth
import AVFoundation
import UIKit
import SwiftData

struct WalletView: View {
    @StateObject private var bleService: BLEService = {
        let service = BLEService()
        service.startScanning() // Start scanning immediately on initialization
        return service
    }()
    @StateObject private var privyService = PrivyService.shared
    @StateObject private var settingsViewModel: SettingsViewModel
    @Environment(\.modelContext) private var modelContext
    @Binding var isLoggedIn: Bool
    @State private var showingRequestForm = false
    @State private var showingSendForm = false
    @State private var amount: String = "1" // Default to 1 MON
    @State private var showingPaymentSuccess = false
    @State private var isLoggingOut = false
    @State private var logoutError: String?
    @State private var isScanning = false // Added state for visual feedback
    @State private var processedRequests = Set<String>() // Track processed payment requests
    @State private var scanTimer: Timer? = nil
    @State private var currentTransactionDetails: [String: String] = [:]
    
    // Haptic feedback generators
    private let paymentSuccessGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    init(isLoggedIn: Binding<Bool>) {
        _isLoggedIn = isLoggedIn
        _settingsViewModel = StateObject(wrappedValue: SettingsViewModel.shared)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Wallet Address Section
                    BalanceView(isMerchantMode: $settingsViewModel.isMerchantMode)
                    
                    if settingsViewModel.selectedMode == .merchant {
                        MerchantView(showingRequestForm: $showingRequestForm, selectionGenerator: selectionGenerator)
                    } else if settingsViewModel.selectedMode == .faucet {
                        FaucetView(
                            isScanning: $isScanning, 
                            showingSendForm: $showingSendForm,
                            selectionGenerator: selectionGenerator,
                            bleService: bleService
                        )
                    } else {
                        CustomerView(
                            isScanning: $isScanning, 
                            showingSendForm: $showingSendForm,
                            selectionGenerator: selectionGenerator,
                            bleService: bleService
                        )
                    }
                    
                    // Payment Requests (visible to customer or faucet)
                    if settingsViewModel.selectedMode != .merchant, let message = bleService.receivedMessage, !hasProcessedRequest(message) {
                        PaymentRequestCard(message: message, bleService: bleService, onPaymentAction: { approved in
                            // Process the payment request only once
                            // Mark this request as processed immediately
                            if let requestId = extractRequestId(from: message) {
                                // Check if we've already processed this specific request
                                guard !processedRequests.contains(requestId) else { return }
                                processedRequests.insert(requestId)
                            }
                            
                            if approved {
                                // Extract transaction details from the message
                                let components = message.split(separator: ":")
                                if components.count >= 3 {
                                    // Generate transaction hash
                                    let txHash = "0x" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
                                    
                                    // Store transaction details
                                    self.currentTransactionDetails = [
                                        "hash": txHash,
                                        "amount": String(components[1]),
                                        "sender": privyService.walletAddress ?? "Unknown",
                                        "recipient": String(components[2]),
                                        "note": components.count >= 4 ? String(components[3]) : ""
                                    ]
                                    
                                    // Save the transaction to SwiftData for the customer
                                    let customerTransaction = PaymentTransaction(
                                        isApproved: true,
                                        transactionHash: txHash,
                                        amount: String(components[1]),
                                        sender: privyService.walletAddress ?? "Unknown",
                                        recipient: String(components[2]),
                                        note: components.count >= 4 ? String(components[3]) : "",
                                        type: .sent,  // Important! This is a SENT transaction for the customer
                                        status: .completed
                                    )
                                    modelContext.insert(customerTransaction)
                                    try? modelContext.save()
                                }
                                
                                playPaymentSound()
                                paymentSuccessGenerator.notificationOccurred(.success)
                                withAnimation {
                                    showingPaymentSuccess = true
                                }
                                // Show success message for longer (5 seconds)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                    withAnimation {
                                        showingPaymentSuccess = false
                                    }
                                }
                            } else {
                                paymentSuccessGenerator.notificationOccurred(.error)
                            }
                            
                            // Clear message and restart scanning after processing
                            bleService.receivedMessage = nil
                            
                            // Restart scanning after a short delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if settingsViewModel.selectedMode != .merchant {
                                    bleService.startScanning()
                                }
                            }
                        })
                        .padding(.horizontal)
                    }
                    
                    // Payment Responses (visible to merchant)
                    if settingsViewModel.selectedMode == .merchant, let message = bleService.receivedMessage {
                        if message.starts(with: "PAYMENT_RESPONSE:") {
                            PaymentResponseCard(message: message)
                                .padding(.horizontal)
                                .onAppear {
                                    if message.contains("APPROVED") {
                                        playPaymentSound()
                                        paymentSuccessGenerator.notificationOccurred(.success)
                                        
                                        // Try to fetch balance with retries
                                        fetchBalanceWithRetry()
                                    } else {
                                        paymentSuccessGenerator.notificationOccurred(.error)
                                    }
                                    
                                    // Clear payment response after displaying
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        bleService.receivedMessage = nil
                                    }
                                }
                        }
                    }
                }
                .padding()
            }
            .refreshable {
                // Refresh balance when pulling down
                await privyService.fetchBalance()
            }
            .overlay {
                if showingPaymentSuccess {
                    PaymentSuccessView(transactionDetails: currentTransactionDetails)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .navigationTitle("Wallet")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView(privyService: privyService, bleService: bleService, isLoggedIn: $isLoggedIn)
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingRequestForm) {
                RequestPaymentFormView(amount: $amount) { amount, note in
                    if let walletAddress = privyService.walletAddress {
                        bleService.broadcastPaymentRequest(amount: amount, walletAddress: walletAddress, note: note)
                    }
                    showingRequestForm = false
                }
            }
            .sheet(isPresented: $showingSendForm) {
                SendMonForm { recipientAddress, amount in
                    Task {
                        do {
                            try await privyService.sendTransaction(amount: amount, to: recipientAddress)
                        } catch {
                            print("Error sending transaction: \(error)")
                        }
                    }
                    showingSendForm = false
                }
            }
            .onChange(of: settingsViewModel.selectedMode) { newValue in
                print("Wallet View: Mode changed to \(newValue)")
                // Stop existing scanning timer
                scanTimer?.invalidate()
                scanTimer = nil
                
                if newValue == .merchant {
                    // Merchant mode: stop scanning
                    bleService.stopScanning()
                    bleService.stopAdvertising() // Stop any previous advertising
                } else {
                    // Customer or Faucet mode: start scanning, stop advertising
                    bleService.stopAdvertising()
                    bleService.startScanning()
                    
                    // Start periodic scanning in customer/faucet mode
                    setupAutoScan()
                }
            }
            .onAppear {
                // Fetch balance with retry when view appears
                fetchBalanceWithRetry()
                
                // Start automatic scanning when not in merchant mode
                if settingsViewModel.selectedMode != .merchant {
                    setupAutoScan()
                }
            }
            .onDisappear {
                // Clean up when view disappears
                scanTimer?.invalidate()
                scanTimer = nil
                bleService.disconnect()
                bleService.stopScanning()
                bleService.stopAdvertising()
            }
        }
        .onReceive(privyService.$authState) { state in
            if case .unauthenticated = state {
                isLoggedIn = false
            }
        }
    }
    
    // Setup auto-scan timer
    private func setupAutoScan() {
        // Cancel any existing timer
        scanTimer?.invalidate()
        
        // Create a new timer that scans every 10 seconds
        scanTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            if settingsViewModel.selectedMode != .merchant && bleService.receivedMessage == nil {
                withAnimation {
                    isScanning = true
                }
                
                // Restart scanning
                bleService.stopScanning()
                bleService.startScanning()
                
                // Reset scanning indicator after 1 second
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation {
                        isScanning = false
                    }
                }
            }
        }
    }
    
    // Extract a unique ID from a payment request message
    private func extractRequestId(from message: String) -> String? {
        if message.starts(with: "PAYMENT_REQUEST:") {
            let components = message.split(separator: ":")
            if components.count >= 3 {
                // Create a unique ID from amount and address
                return "\(components[1]):\(components[2])"
            }
        }
        return nil
    }
    
    // Check if a payment request has already been processed
    private func hasProcessedRequest(_ message: String) -> Bool {
        guard let requestId = extractRequestId(from: message) else {
            return false
        }
        return processedRequests.contains(requestId)
    }
    
    private func playPaymentSound() {
        AudioServicesPlaySystemSound(1407) // This is Apple Pay's success sound
    }
    
    private func sendMon() {
        Task {
            do {
                try await privyService.sendTransaction(amount: privyService.defaultAmount, to: privyService.defaultRecipientAddress)
            } catch {
                print("Error sending transaction: \(error)")
            }
        }
    }
    
    // Add this function to your WalletView struct
    private func fetchBalanceWithRetry(attempts: Int = 3, delay: Double = 1.0) {
        Task {
            var currentAttempt = 0
            var success = false
            
            while currentAttempt < attempts && !success {
                currentAttempt += 1
                
                do {
                    // Try to fetch balance
                    await privyService.fetchBalance()
                    success = true
                } catch {
                    print("Balance fetch attempt \(currentAttempt) failed: \(error)")
                    
                    if currentAttempt < attempts {
                        // Wait before retrying
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                }
            }
        }
    }
}

// Add this new view outside the WalletView struct
struct MerchantView: View {
    @Binding var showingRequestForm: Bool
    let selectionGenerator: UISelectionFeedbackGenerator
    
    var body: some View {
        Button(action: {
            selectionGenerator.selectionChanged()
            showingRequestForm = true
        }) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 24))
                Text("Request Payment")
                    .font(.headline)
            }
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(15)
        }
        .padding(.horizontal)
    }
}

// Add this CustomerView struct after the MerchantView
struct CustomerView: View {
    @Binding var isScanning: Bool
    @Binding var showingSendForm: Bool
    let selectionGenerator: UISelectionFeedbackGenerator
    let bleService: BLEService
    
    var body: some View {
        // Customer View - shows status and send button
        VStack(spacing: 16) {
            HStack {
                Text(isScanning ? "Scanning..." : "Scanning for payment requests...")
                    .foregroundColor(.secondary)
                
                // Added scan button
                Button(action: {
                    selectionGenerator.selectionChanged()
                    withAnimation {
                        isScanning = true
                    }
                    // Restart scanning
                    bleService.stopScanning()
                    bleService.startScanning()
                    
                    // Reset scanning indicator after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            isScanning = false
                        }
                    }
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 18))
                        Text("Scan")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
            }
            .padding(.top)
            .padding(.horizontal)
            
            Button(action: {
                selectionGenerator.selectionChanged()
                showingSendForm = true
            }) {
                HStack {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 24))
                    Text("Send MON")
                        .font(.headline)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(15)
            }
            .padding(.horizontal)
        }
    }
}

struct FaucetView: View {
    @Binding var isScanning: Bool
    @Binding var showingSendForm: Bool
    let selectionGenerator: UISelectionFeedbackGenerator
    let bleService: BLEService
    
    var body: some View {
        // Customer View - shows status and send button
        VStack(spacing: 16) {
            HStack {
                Text(isScanning ? "Scanning..." : "Scanning for payment requests...")
                    .foregroundColor(.secondary)
                
                // Added scan button
                Button(action: {
                    selectionGenerator.selectionChanged()
                    withAnimation {
                        isScanning = true
                    }
                    // Restart scanning
                    bleService.stopScanning()
                    bleService.startScanning()
                    
                    // Reset scanning indicator after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            isScanning = false
                        }
                    }
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 18))
                        Text("Scan")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
            }
            .padding(.top)
            .padding(.horizontal)
            
            Button(action: {
                selectionGenerator.selectionChanged()
                showingSendForm = true
            }) {
                HStack {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 24))
                    Text("Send MON")
                        .font(.headline)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(15)
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    WalletView(isLoggedIn: .constant(true))
} 
