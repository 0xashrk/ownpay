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
    @Binding var isLoggedIn: Bool
    @State private var showingRequestForm = false
    @State private var amount: String = ""
    @State private var isMerchantMode = false
    @State private var showingPaymentSuccess = false
    
    // Haptic feedback generators
    private let paymentSuccessGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Balance Section
                VStack(spacing: 8) {
                    Text("Balance")
                        .font(.headline)
                    Text("0.1 MON")
                        .font(.title)
                        .bold()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
                
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
                    // Customer View - shows status
                    Text("Scanning for payment requests...")
                        .foregroundColor(.secondary)
                        .padding(.top)
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
                
                // Success overlay
                if showingPaymentSuccess {
                    PaymentSuccessView()
                        .transition(.scale.combined(with: .opacity))
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
                
                Spacer()
                
                // Logout Button
                Button(action: {
                    bleService.disconnect()
                    bleService.stopScanning()
                    bleService.stopAdvertising()
                    isLoggedIn = false
                }) {
                    Text("Logout")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding()
            }
            .padding()
            .navigationTitle("Wallet")
            .sheet(isPresented: $showingRequestForm) {
                RequestPaymentForm(amount: $amount) { amount in
                    bleService.broadcastPaymentRequest(amount: amount, walletAddress: "YOUR_WALLET_HERE")
                    showingRequestForm = false
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
    }
    
    private func playPaymentSound() {
        AudioServicesPlaySystemSound(1407) // This is Apple Pay's success sound
    }
}

struct PaymentRequestCard: View {
    let message: String
    let bleService: BLEService
    let onPaymentAction: (Bool) -> Void
    
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
                            bleService.sendPaymentResponse(approved: true)
                            onPaymentAction(true)
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

struct RequestPaymentForm: View {
    @Binding var amount: String
    let onRequest: (Double) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Request Amount")) {
                    TextField("Amount (MON)", text: $amount)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Request Payment")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Request") {
                    if let amountDouble = Double(amount) {
                        onRequest(amountDouble)
                    }
                }
                .disabled(amount.isEmpty)
            )
        }
    }
}

#Preview {
    WalletView(isLoggedIn: .constant(true))
} 
