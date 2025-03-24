import SwiftUI

// Extension to dismiss keyboard
extension View {
    func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

struct RequestPaymentFormView: View, Hashable {
    @StateObject private var viewModel: RequestPaymentViewModel
    @Environment(\.dismiss) var dismiss
    let selectedFriend: Friend?
    @State private var isSubmitting = false
    @State private var error: Error?
    
    init(amount: Binding<String>, 
         selectedFriend: Friend? = nil,
         onRequest: @escaping (Double, String) -> Void) {
        let defaultAmount = "0.025"
        if amount.wrappedValue.isEmpty || amount.wrappedValue == "1" {
            amount.wrappedValue = defaultAmount
        }
        self.selectedFriend = selectedFriend
        _viewModel = StateObject(wrappedValue: RequestPaymentViewModel(amount: amount, onRequest: onRequest))
    }
    
    private func submitRequest() {
        guard let amount = Double(viewModel.amount) else { return }
        
        if let friend = selectedFriend {
            Task {
                isSubmitting = true
                do {
                    let response = try await APIService.shared.createPaymentRequest(
                        friendId: friend.id,
                        amount: Decimal(amount),
                        note: viewModel.note.isEmpty ? nil : viewModel.note
                    )
                    await MainActor.run {
                        isSubmitting = false
                        NotificationCenter.default.post(name: .dismissFriendPicker, object: nil)
                    }
                } catch {
                    await MainActor.run {
                        self.error = error
                        isSubmitting = false
                    }
                }
            }
        } else {
            viewModel.submitRequest()
        }
    }
    
    // Add this computed property to format and validate input
    private var formattedAmount: Binding<String> {
        Binding(
            get: { viewModel.amount },
            set: { newValue in
                // Only allow numbers and one decimal point
                let filtered = newValue.filter { "0123456789.".contains($0) }
                
                // Handle decimal places
                if filtered.contains(".") {
                    let components = filtered.split(separator: ".")
                    if components.count == 2 {
                        // Limit to 2 decimal places
                        let decimals = String(components[1].prefix(2))
                        viewModel.amount = "\(components[0]).\(decimals)"
                    } else {
                        viewModel.amount = filtered
                    }
                } else {
                    viewModel.amount = filtered
                }
            }
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Request Amount")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    TextField("Amount (MON)", text: formattedAmount)
                        .padding()
                        .keyboardType(.decimalPad)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    
                    Text("Quick Amounts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    
                    HStack(spacing: 8) {
                        ForEach(viewModel.quickPaymentAmounts, id: \.self) { amount in
                            Button(action: {
                                viewModel.setQuickPaymentAmount(amount)
                            }) {
                                Text(String(format: "%.2f", amount))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.blue.opacity(0.8))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.blue, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Note (Optional)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    TextField("What's this for? (e.g., Coffee, Lunch)", text: $viewModel.note)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    
                    Text("Quick Notes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    
                    HStack(spacing: 8) {
                        Button(action: {
                            viewModel.note = "Faucet"
                        }) {
                            Text("Faucet")
                                .font(.system(.body, design: .default))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.green.opacity(0.8))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.green, lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            viewModel.note = "Coffee"
                        }) {
                            Text("Coffee")
                                .font(.system(.body, design: .default))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.green.opacity(0.8))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.green, lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            viewModel.note = "Lunch"
                        }) {
                            Text("Lunch")
                                .font(.system(.body, design: .default))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.green.opacity(0.8))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.green, lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button(action: submitRequest) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 8)
                        }
                        Text(isSubmitting ? "Requesting..." : "Request Payment")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(viewModel.isRequestEnabled ? Color.blue : Color.gray)
                    )
                    .padding(.horizontal)
                }
                .disabled(!viewModel.isRequestEnabled || isSubmitting)
                .padding(.bottom, 20)
            }
            .padding(.top, 20)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            hideKeyboard()
        }
        .toolbar {
            if selectedFriend == nil {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: .constant(error != nil)) {
            Button("OK") {
                error = nil
            }
        } message: {
            if let error = error {
                Text(error.localizedDescription)
            }
        }
    }
    
    // Add these methods for Hashable conformance
    static func == (lhs: RequestPaymentFormView, rhs: RequestPaymentFormView) -> Bool {
        lhs.selectedFriend?.id == rhs.selectedFriend?.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(selectedFriend?.id)
    }
} 