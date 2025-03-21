import SwiftUI

struct SendMonForm: View {
    @StateObject private var privyService = PrivyService.shared
    @State private var recipientAddress: String = ""
    @State private var amount: String = ""
    @State private var showMaxAmountWarning = false
    @State private var errorMessage = ""
    
    let onSend: (String, Double) -> Void
    @Environment(\.dismiss) var dismiss
    
    // Gas buffer - leave at least this much MON for gas fees
    private let gasBuffer: Double = 0.01
    
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
            Form {
                Section(header: Text("Recipient Address")) {
                    TextField("Enter wallet address", text: $recipientAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onAppear {
                            recipientAddress = privyService.defaultRecipientAddress
                        }
                }
                
                Section(header: 
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Amount")
                        if maxAmount > 0 {
                            Text("Maximum: \(String(format: "%.5f", maxAmount)) MON")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                ) {
                    TextField("Amount (MON)", text: $amount)
                        .keyboardType(.decimalPad)
                        .onAppear {
                            // Set default amount, but ensure it's not greater than max
                            let defaultAmount = min(privyService.defaultAmount, maxAmount)
                            amount = String(format: "%.2f", defaultAmount)
                        }
                        .onChange(of: amount) { newValue in
                            validateAmount()
                        }
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Button("Use Maximum Amount") {
                        amount = String(format: "%.5f", maxAmount)
                    }
                    .disabled(maxAmount <= 0)
                }
            }
            .navigationTitle("Send MON")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Send") {
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
                }
                .disabled(!isAmountValid || recipientAddress.isEmpty)
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

// Add preview
#Preview {
    SendMonForm { recipientAddress, amount in
        print("Would send \(amount) MON to \(recipientAddress)")
    }
}
