import SwiftUI

struct WalletView: View {
    @StateObject private var bleService = BLEService()
    @Binding var isLoggedIn: Bool
    @State private var showingPaymentRequest = false
    @State private var amount: String = ""
    @State private var walletAddress: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Balance Section
                VStack(spacing: 8) {
                    Text("Balance")
                        .font(.headline)
                    Text("0.1 ETH")
                        .font(.title)
                        .bold()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
                
                // Connection Status
                HStack {
                    Circle()
                        .fill(connectionStatusColor)
                        .frame(width: 10, height: 10)
                    Text(connectionStatusText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Payment Request Section
                VStack(spacing: 16) {
                    Button(action: {
                        showingPaymentRequest = true
                    }) {
                        Text("Request Payment")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(bleService.connectionState != .connected)
                    
                    if let message = bleService.receivedMessage {
                        PaymentRequestView(message: message)
                    }
                }
                .padding()
                
                Spacer()
                
                // Logout Button
                Button(action: {
                    bleService.disconnect()
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
            .sheet(isPresented: $showingPaymentRequest) {
                PaymentRequestForm(amount: $amount, walletAddress: $walletAddress) { amount, walletAddress in
                    bleService.broadcastPaymentRequest(amount: amount, walletAddress: walletAddress)
                    showingPaymentRequest = false
                }
            }
        }
    }
    
    private var connectionStatusColor: Color {
        switch bleService.connectionState {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .red
        }
    }
    
    private var connectionStatusText: String {
        switch bleService.connectionState {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        }
    }
}

struct PaymentRequestView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Payment Request")
                .font(.headline)
            
            if message.starts(with: "PAYMENT_REQUEST:") {
                let components = message.split(separator: ":")
                if components.count >= 3 {
                    Text("Amount: \(components[1]) ETH")
                        .font(.subheadline)
                    Text("Wallet: \(components[2])")
                        .font(.subheadline)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)
    }
}

struct PaymentRequestForm: View {
    @Binding var amount: String
    @Binding var walletAddress: String
    let onSubmit: (Double, String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Payment Details")) {
                    TextField("Amount (ETH)", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    TextField("Wallet Address", text: $walletAddress)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Request Payment")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Request") {
                    if let amountDouble = Double(amount) {
                        onSubmit(amountDouble, walletAddress)
                        dismiss()
                    }
                }
                .disabled(amount.isEmpty || walletAddress.isEmpty)
            )
        }
    }
}

#Preview {
    WalletView(isLoggedIn: .constant(true))
} 