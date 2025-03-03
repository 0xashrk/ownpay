import SwiftUI
import CoreBluetooth

struct WalletView: View {
    @StateObject private var bleService = BLEService()
    @Binding var isLoggedIn: Bool
    @State private var showingRequestForm = false
    @State private var amount: String = ""
    @State private var isMerchantMode = false
    
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
                
                // Mode Toggle
                Picker("Mode", selection: $isMerchantMode) {
                    Text("Customer").tag(false)
                    Text("Merchant").tag(true)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                if isMerchantMode {
                    // Merchant View
                    Button(action: {
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
                    Text(bleService.isScanning ? "Scanning for payment requests..." : "Ready to pay")
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
                
                // Payment Requests (visible to customer)
                if !isMerchantMode, let message = bleService.receivedMessage {
                    PaymentRequestCard(message: message, bleService: bleService)
                        .padding(.horizontal)
                }
                
                // Payment Responses (visible to merchant)
                if isMerchantMode, let message = bleService.receivedMessage {
                    if message.starts(with: "PAYMENT_RESPONSE:") {
                        PaymentResponseCard(message: message)
                            .padding(.horizontal)
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
                } else {
                    // Customer mode: start scanning, stop advertising
                    bleService.stopAdvertising()
                    bleService.startScanning()
                }
            }
            .onAppear {
                // Start in customer mode by default
                bleService.startScanning()
            }
        }
    }
}

struct PaymentRequestCard: View {
    let message: String
    let bleService: BLEService
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Payment Request")
                .font(.headline)
            
            if message.starts(with: "PAYMENT_REQUEST:") {
                let components = message.split(separator: ":")
                if components.count >= 3 {
                    Text("Amount: \(components[1]) ETH")
                        .font(.title2)
                        .bold()
                    Text("From: \(components[2])")
                        .font(.subheadline)
                        .lineLimit(1)
                        
                    HStack(spacing: 20) {
                        Button(action: {
                            bleService.sendPaymentResponse(approved: false)
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

struct RequestPaymentForm: View {
    @Binding var amount: String
    let onRequest: (Double) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Request Amount")) {
                    TextField("Amount (ETH)", text: $amount)
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