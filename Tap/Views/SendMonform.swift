import SwiftUI

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
