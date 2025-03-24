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
    @State private var amount: String = "0.025" // Default to 0.025 MON
    @State private var showingPaymentSuccess = false
    @State private var isLoggingOut = false
    @State private var logoutError: String?
    @State private var isScanning = false // Added state for visual feedback
    @State private var processedRequests = Set<String>() // Track processed payment requests
    @State private var scanTimer: Timer? = nil
    @State private var currentTransactionDetails: [String: String] = [:]
    @StateObject private var paymentViewModel = PaymentViewModel()
    
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
                        .padding(.bottom, 5)
                    
                    if settingsViewModel.selectedMode == .merchant {
                        MerchantView(
                            showingRequestForm: $showingRequestForm,
                            showingSendForm: $showingSendForm,
                            selectionGenerator: selectionGenerator,
                            isScanning: $isScanning,
                            bleService: bleService
                        )
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
                    if settingsViewModel.selectedMode != .merchant,
                       let message = bleService.receivedMessage,
                       !paymentViewModel.hasProcessedRequest(message) {
                        
                        PaymentRequestCard(
                            message: message,
                            bleService: bleService,
                            settingsViewModel: settingsViewModel,
                            onPaymentAction: { approved in
                                _ = paymentViewModel.processPaymentRequest(
                                    message: message,
                                    approved: approved,
                                    modelContext: modelContext,
                                    privyService: privyService,
                                    bleService: bleService,
                                    settingsViewModel: settingsViewModel,
                                    playSound: playPaymentSound
                                )
                            }
                        )
                        .padding(.horizontal)
                    }
                    
                    // Payment Responses (visible to merchant)
                    if settingsViewModel.selectedMode == .merchant,
                       let message = bleService.receivedMessage,
                       message.starts(with: "PAYMENT_RESPONSE:") {
                        
                        PaymentResponseCard(message: message)
                            .padding(.horizontal)
                            .onAppear {
                                paymentViewModel.processPaymentResponse(
                                    message: message,
                                    bleService: bleService,
                                    fetchBalance: { fetchBalanceWithRetry() },
                                    playSound: playPaymentSound
                                )
                            }
                    }
                }
                .padding(.vertical)
                Text("Created by own.fun")
                    .foregroundStyle(Color.secondary)
                    .font(.caption)
            }
//            Text("Hello")
            .refreshable {
                // Refresh balance when pulling down
                await privyService.fetchBalance()
            }
            .overlay {
                if paymentViewModel.showingPaymentSuccess {
                    PaymentSuccessView(transactionDetails: paymentViewModel.currentTransactionDetails)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .navigationTitle(settingsViewModel.selectedMode == .faucet ? "Faucet" : "Wallet")
            .navigationBarTitleDisplayMode(.inline)
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
            .alert(
                "Faucet Alert",
                isPresented: $paymentViewModel.showingFaucetAlert,
                actions: {
                    Button("OK") {
                        paymentViewModel.showingFaucetAlert = false
                    }
                },
                message: {
                    Text(paymentViewModel.faucetAlertMessage)
                }
            )
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

#Preview {
    WalletView(isLoggedIn: .constant(true))
} 
