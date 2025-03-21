import SwiftUI

struct SendMonForm: View {
    @StateObject private var privyService = PrivyService.shared
    @State private var recipientAddress: String = ""
    @State private var amount: String = ""
    @State private var showMaxAmountWarning = false
    @State private var errorMessage = ""
    
    let onSend: (String, Double) -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // Gas buffer - leave at least this much MON for gas fees
    private let gasBuffer: Double = 0.01
    
    // Theme colors
    private var accentColor: Color { Color.blue }
    private var errorColor: Color { Color.red }
    private var backgroundColor: Color { colorScheme == .dark ? Color.black.opacity(0.6) : Color.white }
    private var secondaryBgColor: Color { colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1) }
    
    private var maxAmount: Double {
        guard let balanceStr = privyService.balance else { return 0 }
        
        // Extract the numeric part of the balance string (e.g., "10.5 MON" -> 10.5)
        let components = balanceStr.components(separatedBy: " ")
        guard let amountStr = components.first,
              let balance = Double(amountStr) else {
            return 0
        }
        
        // Return max amount user can send (balance minus gas buffer)
        return max(0, balance - gasBuffer)
    }
    
    private var isAmountValid: Bool {
        guard let amountDouble = Double(amount) else { return false }
        return amountDouble > 0 && amountDouble <= maxAmount
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Balance Info Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Available Balance")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let balance = privyService.balance {
                            Text(balance)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(accentColor)
                        } else {
                            Text("Loading balance...")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                            Text("Maximum send amount: \(String(format: "%.5f", maxAmount)) MON")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(secondaryBgColor)
                    .cornerRadius(12)
                    
                    // Recipient Address
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recipient Address")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: "wallet.pass")
                                .foregroundColor(.secondary)
                            
                            TextField("Enter wallet address", text: $recipientAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(10)
                                .background(secondaryBgColor)
                                .cornerRadius(8)
                        }
                    }
                    
                    // Amount
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: "creditcard")
                                .foregroundColor(.secondary)
                            
                            TextField("0.00", text: $amount)
                                .keyboardType(.decimalPad)
                                .padding(10)
                                .background(secondaryBgColor)
                                .cornerRadius(8)
                                .onChange(of: amount) { newValue in
                                    validateAmount()
                                }
                            
                            Text("MON")
                                .foregroundColor(.secondary)
                                .padding(.trailing, 10)
                        }
                        
                        if !errorMessage.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(errorColor)
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(errorColor)
                            }
                            .padding(.top, 4)
                        }
                        
                        Button(action: {
                            amount = String(format: "%.5f", maxAmount)
                        }) {
                            HStack {
                                Image(systemName: "arrow.up.to.line")
                                Text("Use Maximum Amount")
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(accentColor.opacity(0.1))
                            .foregroundColor(accentColor)
                            .cornerRadius(8)
                        }
                        .disabled(maxAmount <= 0)
                        .padding(.top, 8)
                    }
                    
                    Spacer()
                    
                    // Send Button
                    Button(action: {
                        if let amountDouble = Double(amount), isAmountValid {
                            Task {
                                do {
                                    try await privyService.sendTransaction(amount: amountDouble, to: recipientAddress)
                                } catch {
                                    print("Error sending transaction: \(error)")
                                }
                            }
                            dismiss()
                        }
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Send \(amount.isEmpty ? "MON" : "\(amount) MON")")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isAmountValid && !recipientAddress.isEmpty ? accentColor : accentColor.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(15)
                    }
                    .disabled(!isAmountValid || recipientAddress.isEmpty)
                }
                .padding()
            }
            .onAppear {
                recipientAddress = privyService.defaultRecipientAddress
                let defaultAmount = min(privyService.defaultAmount, maxAmount)
                amount = String(format: "%.2f", defaultAmount)
                validateAmount()
            }
            .navigationTitle("Send MON")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
            )
            .alert(isPresented: $showMaxAmountWarning) {
                Alert(
                    title: Text("Invalid Amount"),
                    message: Text("Please enter an amount that is greater than 0 and less than your maximum available balance (balance minus gas fee)."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func validateAmount() {
        guard !amount.isEmpty else {
            errorMessage = ""
            return
        }
        
        guard let amountDouble = Double(amount) else {
            errorMessage = "Please enter a valid number"
            return
        }
        
        if amountDouble <= 0 {
            errorMessage = "Amount must be greater than 0"
        } else if amountDouble > maxAmount {
            errorMessage = "Amount exceeds your available balance (including gas fee)"
        } else {
            errorMessage = ""
        }
    }
}

#Preview {
    SendMonForm { recipientAddress, amount in
        print("Would send \(amount) MON to \(recipientAddress)")
    }
}
