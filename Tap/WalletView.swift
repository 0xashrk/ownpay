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
    @Binding var isLoggedIn: Bool
    @State private var showingRequestForm = false
    @State private var showingSendForm = false
    @State private var amount: String = "1" // Default to 1 MON
    @State private var isMerchantMode = false
    @State private var showingPaymentSuccess = false
    @State private var isLoggingOut = false
    @State private var logoutError: String?
    @State private var isScanning = false // Added state for visual feedback
    
    // Haptic feedback generators
    private let paymentSuccessGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Wallet Address Section
                    BalanceView(isMerchantMode: $isMerchantMode)
                    
                    // Mode Toggle with haptic
                    Picker("Mode", selection: $isMerchantMode) {
                        Text("Customer").tag(false)
                        Text("Merchant").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .onChange(of: isMerchantMode) { _ in
                        selectionGenerator.selectionChanged()
                    }
                    
                    if isMerchantMode {
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
                    if !isMerchantMode, let message = bleService.receivedMessage {
                        PaymentRequestCard(message: message, bleService: bleService, onPaymentAction: { approved in
                            if approved {
                                playPaymentSound()
                                paymentSuccessGenerator.notificationOccurred(.success)
                                withAnimation {
                                    showingPaymentSuccess = true
                                }
                                // Hide success message after 2 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation {
                                        showingPaymentSuccess = false
                                    }
                                }
                            } else {
                                paymentSuccessGenerator.notificationOccurred(.error)
                            }
                        })
                        .padding(.horizontal)
                    }
                    
                    // Payment Responses (visible to merchant)
                    if isMerchantMode, let message = bleService.receivedMessage {
                        if message.starts(with: "PAYMENT_RESPONSE:") {
                            PaymentResponseCard(message: message)
                                .padding(.horizontal)
                                .onAppear {
                                    if message.contains("APPROVED") {
                                        playPaymentSound()
                                        paymentSuccessGenerator.notificationOccurred(.success)
                                    } else {
                                        paymentSuccessGenerator.notificationOccurred(.error)
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
                    PaymentSuccessView()
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
                RequestPaymentFormView(amount: $amount) { amount in
                    if let walletAddress = privyService.walletAddress {
                        bleService.broadcastPaymentRequest(amount: amount, walletAddress: walletAddress)
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
            .onChange(of: isMerchantMode) { newValue in
                if newValue {
                    // Merchant mode: stop scanning
                    bleService.stopScanning()
                    bleService.stopAdvertising() // Stop any previous advertising
                } else {
                    // Customer mode: start scanning, stop advertising
                    bleService.stopAdvertising()
                    bleService.startScanning()
                }
            }
            .onDisappear {
                // Clean up when view disappears
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
}

struct PaymentRequestCard: View {
    let message: String
    let bleService: BLEService
    let onPaymentAction: (Bool) -> Void
    @StateObject private var privyService = PrivyService.shared
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Payment Request")
                .font(.headline)
            
            if message.starts(with: "PAYMENT_REQUEST:") {
                let components = message.split(separator: ":")
                if components.count >= 3 {
                    Text("Amount: \(components[1]) MON")
                        .font(.title2)
                        .bold()
                    Text("From: \(components[2])")
                        .font(.subheadline)
                        .lineLimit(1)
                        
                    HStack(spacing: 20) {
                        Button(action: {
                            bleService.stopAdvertising() // Stop broadcasting
                            bleService.sendPaymentResponse(approved: false)
                            onPaymentAction(false)
                        }) {
                            Text("Decline")
                                .foregroundColor(.red)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 20)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            // Send the actual transaction
                            if let amount = Double(components[1]),
                               let recipientAddress = String(components[2]) as String? {
                                Task {
                                    do {
                                        try await privyService.sendTransaction(amount: amount, to: recipientAddress)
                                        // Only send the response after transaction is successful
                                        bleService.stopAdvertising() // Stop broadcasting
                                        bleService.sendPaymentResponse(approved: true)
                                        onPaymentAction(true)
                                    } catch {
                                        print("Error sending transaction: \(error)")
                                        // Send declined response if transaction fails
                                        bleService.stopAdvertising() // Stop broadcasting
                                        bleService.sendPaymentResponse(approved: false)
                                        onPaymentAction(false)
                                    }
                                }
                            }
                        }) {
                            Text("Pay")
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 20)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
}

struct PaymentResponseCard: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Payment Response")
                .font(.headline)
            
            let isApproved = message.contains("APPROVED")
            Image(systemName: isApproved ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(isApproved ? .green : .red)
            
            Text(isApproved ? "Payment Approved" : "Payment Declined")
                .font(.title3)
                .foregroundColor(isApproved ? .green : .red)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct PaymentSuccessView: View {
    var body: some View {
        VStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            Text("Payment Sent!")
                .font(.title2)
                .bold()
        }
        .padding(30)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
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

#Preview {
    WalletView(isLoggedIn: .constant(true))
} 
