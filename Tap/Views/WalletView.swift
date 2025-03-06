import SwiftUI
import CoreBluetooth
import AVFoundation
import UIKit

struct WalletView: View {
    @StateObject private var bleService: BLEService = {
        let service = BLEService()
        service.startScanning() // Start scanning immediately on initialization
        return service
    }()
    @StateObject private var privyService = PrivyService.shared
    @StateObject private var settingsViewModel: SettingsViewModel
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
        _settingsViewModel = StateObject(wrappedValue: SettingsViewModel(
            privyService: PrivyService.shared,
            bleService: BLEService()
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Wallet Address Section
                    BalanceView(isMerchantMode: $settingsViewModel.isMerchantMode)
                    
                    if settingsViewModel.isMerchantMode {
                        // Merchant View
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
                    } else {
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
                    
                    // Payment Requests (visible to customer)
                    if !settingsViewModel.isMerchantMode, let message = bleService.receivedMessage, !hasProcessedRequest(message) {
                        PaymentRequestCard(message: message, bleService: bleService, onPaymentAction: { approved in
                            // Mark this request as processed
                            if let requestId = extractRequestId(from: message) {
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
                                if !settingsViewModel.isMerchantMode {
                                    bleService.startScanning()
                                }
                            }
                        })
                        .padding(.horizontal)
                    }
                    
                    // Payment Responses (visible to merchant)
                    if settingsViewModel.isMerchantMode, let message = bleService.receivedMessage {
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
            .onChange(of: settingsViewModel.isMerchantMode) { newValue in
                // Stop existing scanning timer
                scanTimer?.invalidate()
                scanTimer = nil
                
                if newValue {
                    // Merchant mode: stop scanning
                    bleService.stopScanning()
                    bleService.stopAdvertising() // Stop any previous advertising
                } else {
                    // Customer mode: start scanning, stop advertising
                    bleService.stopAdvertising()
                    bleService.startScanning()
                    
                    // Start periodic scanning in customer mode
                    setupAutoScan()
                }
            }
            .onAppear {
                // Fetch balance with retry when view appears
                fetchBalanceWithRetry()
                
                // Start automatic scanning when in customer mode
                if !settingsViewModel.isMerchantMode {
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
            if !settingsViewModel.isMerchantMode && bleService.receivedMessage == nil {
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

struct SendMonForm: View {
    @StateObject private var privyService = PrivyService.shared
    @State private var recipientAddress: String = ""
    @State private var amount: String = ""
    let onSend: (String, Double) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Recipient Address")) {
                    TextField("Enter wallet address", text: $recipientAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onAppear {
                            recipientAddress = privyService.defaultRecipientAddress
                        }
                }
                
                Section(header: Text("Amount")) {
                    TextField("Amount (MON)", text: $amount)
                        .keyboardType(.decimalPad)
                        .onAppear {
                            amount = String(format: "%.2f", privyService.defaultAmount)
                        }
                }
            }
            .navigationTitle("Send MON")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Send") {
                    if let amountDouble = Double(amount) {
                        Task {
                            do {
                                try await privyService.sendTransaction(amount: amountDouble, to: recipientAddress)
                            } catch {
                                print("Error sending transaction: \(error)")
                            }
                        }
                        dismiss()
                    }
                }
                .disabled(recipientAddress.isEmpty || amount.isEmpty)
            )
        }
    }
}

struct PaymentSuccessView: View {
    var transactionDetails: [String: String]
    
    var body: some View {
        VStack(spacing: 16) {
            // Success header
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                
                Text("Payment Sent!")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 4)
            
            // Transaction details section
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                
                if let amount = transactionDetails["amount"] {
                    HStack {
                        Text("Amount:")
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(amount) MON")
                            .fontWeight(.semibold)
                    }
                }
                
                if let sender = transactionDetails["sender"] {
                    HStack {
                        Text("From:")
                            .fontWeight(.medium)
                        Spacer()
                        Text(sender)
                            .fontWeight(.regular)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                if let recipient = transactionDetails["recipient"] {
                    HStack {
                        Text("To:")
                            .fontWeight(.medium)
                        Spacer()
                        Text(recipient)
                            .fontWeight(.regular)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                if let note = transactionDetails["note"], !note.isEmpty {
                    HStack(alignment: .top) {
                        Text("Note:")
                            .fontWeight(.medium)
                        Spacer()
                        Text(note)
                            .fontWeight(.regular)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                if let hash = transactionDetails["hash"] {
                    Divider()
                    .padding(.vertical, 4)
                    
                    HStack {
                        Text("Tx Hash:")
                            .fontWeight(.medium)
                            .font(.subheadline)
                        Spacer()
                        Text(hash)
                            .fontWeight(.regular)
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .frame(maxWidth: 350)
    }
}

#Preview {
    WalletView(isLoggedIn: .constant(true))
} 
