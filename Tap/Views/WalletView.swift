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
    @StateObject private var merchantViewModel = MerchantViewModel()
    
    // Haptic feedback generators
    private let paymentSuccessGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    init(isLoggedIn: Binding<Bool>) {
        _isLoggedIn = isLoggedIn
        _settingsViewModel = StateObject(wrappedValue: SettingsViewModel.shared)
    }
    
    var body: some View {
        NavigationStack(path: $settingsViewModel.navigationPath) {
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
                            bleService: bleService,
                            viewModel: merchantViewModel
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
                    
                    Text("Created by own.fun")
                        .foregroundStyle(Color.secondary)
                        .font(.caption)
                }
                .padding(.vertical)
            }
            .overlay {
                if let message = bleService.receivedMessage,
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
            }
            .refreshable {
                // Create a task group to fetch both balance and requests concurrently
                await withTaskGroup(of: Void.self) { group in
                    // Fetch balance
                    group.addTask {
                        await privyService.fetchBalance()
                    }
                    
                    // Refresh requests if in merchant mode
                    if settingsViewModel.selectedMode == .merchant {
                        group.addTask {
                            await merchantViewModel.refreshRequests()
                        }
                    }
                    
                    // Wait for all tasks to complete
                    await group.waitForAll()
                }
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
                    NavigationLink(value: "settings") {
                        Image(systemName: "gear")
                    }
                }
            }
            .navigationDestination(for: String.self) { destination in
                switch destination {
                case "settings":
                    SettingsView(privyService: privyService, bleService: bleService, isLoggedIn: $isLoggedIn)
                case "transactionHistory":
                    TransactionHistoryView()
                default:
                    EmptyView()
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
                scanTimer?.invalidate()
                scanTimer = nil
                
                bleService.stopAdvertising()
                bleService.startScanning()
                setupAutoScan()
            }
            .onAppear {
                fetchBalanceWithRetry()
                if settingsViewModel.selectedMode != .merchant {
                    setupAutoScan()
                }
            }
            .onDisappear {
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
        .environmentObject(settingsViewModel)
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
