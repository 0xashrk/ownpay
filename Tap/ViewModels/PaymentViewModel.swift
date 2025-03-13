import SwiftUI
import SwiftData
import AVFoundation

class PaymentViewModel: ObservableObject {
    @Published var showingPaymentSuccess = false
    @Published var currentTransactionDetails: [String: String] = [:]
    @Published var processedRequests = Set<String>()
    @Published var showingFaucetAlert = false
    @Published var faucetAlertMessage = ""
    
    private let paymentSuccessGenerator = UINotificationFeedbackGenerator()
    
    // Extracts a unique ID from a payment request message
    func extractRequestId(from message: String) -> String? {
        if message.starts(with: "PAYMENT_REQUEST:") {
            let components = message.split(separator: ":")
            
            // If the message includes a request ID (5 components)
            if components.count >= 5 {
                // Use the actual unique ID from the message
                return String(components[4])
            }
            // Fallback for backward compatibility with older message format
            else if components.count >= 3 {
                // Legacy method: Create ID from amount and address
                return "\(components[1]):\(components[2])"
            }
        }
        return nil
    }
    
    // Check if a payment request has already been processed
    func hasProcessedRequest(_ message: String) -> Bool {
        guard let requestId = extractRequestId(from: message) else {
            return false
        }
        return processedRequests.contains(requestId)
    }
    
    // Process a faucet mode payment
    func processFaucetPayment(message: String, modelContext: ModelContext) -> Bool {
        let components = message.split(separator: ":")
        if components.count < 3 { return true }
        
        let recipient = String(components[2])
        let requestedAmount = Double(String(components[1])) ?? 0.0
        
        // Create a descriptor to query SwiftData
        let descriptor = FetchDescriptor<PaymentTransaction>()
        
        do {
            // Query SwiftData for all transactions
            let allPayments = try modelContext.fetch(descriptor)
            
            // Filter in memory for relevant transactions
            let matchingPayments = allPayments.filter {
                if let paymentRecipient = $0.recipient {
                    return paymentRecipient == recipient && $0.isApproved == true
                }
                return false
            }
            
            // Calculate total amount sent to this address
            var totalSent = 0.0
            for payment in matchingPayments {
                if let amountString = payment.amount, 
                   let amount = Double(amountString) {
                    totalSent += amount
                }
            }
            
            print("🚰 FAUCET MODE: Recipient \(recipient) has received \(totalSent) MON in total")
            print("🚰 FAUCET MODE: Recipient \(recipient) has \(matchingPayments.count) total transactions")
            
            // Check if the new request would exceed the limit (0.05 MON)
            if totalSent + requestedAmount > 0.05 {
                print("⛔️ FAUCET LIMIT EXCEEDED: Request for \(requestedAmount) MON would exceed the 0.05 MON limit")
                return false // Don't allow the payment
            }
            
            return true // Allow the payment
        } catch {
            print("Error fetching previous payments: \(error)")
            return true // On error, allow the payment to avoid blocking legitimate requests
        }
    }
    
    // Process any payment request - returns true if handled successfully
    func processPaymentRequest(
        message: String, 
        approved: Bool, 
        modelContext: ModelContext,
        privyService: PrivyService,
        bleService: BLEService,
        settingsViewModel: SettingsViewModel,
        playSound: () -> Void
    ) -> Bool {
        // Check if already processed
        if let requestId = extractRequestId(from: message) {
            if processedRequests.contains(requestId) { return false }
            processedRequests.insert(requestId)
        }
        
        // Extract transaction details from the message
        let components = message.split(separator: ":")
        if components.count < 3 { return false }
        
        // For faucet mode: check limit before approving
        var shouldReject = false
        if settingsViewModel.selectedMode == .faucet && approved {
            let allowPayment = processFaucetPayment(message: message, modelContext: modelContext)
            if !allowPayment {
                // Show alert for faucet limit
                faucetAlertMessage = "Payment rejected: This wallet has already received more than 0.05 MON."
                showingFaucetAlert = true
                
                // Mark as not approved - this will prevent actual payment
                shouldReject = true
                
                // Log the rejection attempt (optional)
                print("⛔️ PAYMENT REJECTED: Faucet limit exceeded")
            }
        }
        
        // Only proceed with payment if approved AND not rejected due to limits
        if approved && !shouldReject {
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
                type: .sent,
                status: .completed
            )
            modelContext.insert(customerTransaction)
            try? modelContext.save()
            
            playSound()
            paymentSuccessGenerator.notificationOccurred(.success)
            withAnimation {
                showingPaymentSuccess = true
            }
            
            // Show success message for longer (5 seconds)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation {
                    self.showingPaymentSuccess = false
                }
            }
        } else {
            // Transaction was rejected - either manually or due to limit
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
        
        return true // Successfully handled
    }
    
    // Process payment response
    func processPaymentResponse(
        message: String, 
        bleService: BLEService,
        fetchBalance: () -> Void,
        playSound: () -> Void
    ) {
        if message.contains("APPROVED") {
            playSound()
            paymentSuccessGenerator.notificationOccurred(.success)
            fetchBalance()
        } else {
            // Disable error sound temporarily
            // AudioServicesPlaySystemSound(1073) // Commented out error sound
            paymentSuccessGenerator.notificationOccurred(.error)
        }
        
        // Clear payment response after displaying
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            bleService.receivedMessage = nil
        }
    }
} 
