import SwiftUI

// Extension to dismiss keyboard
extension View {
    func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

struct RequestPaymentFormView: View {
    @StateObject private var viewModel: RequestPaymentViewModel
    @Environment(\.dismiss) var dismiss
    
    init(amount: Binding<String>, onRequest: @escaping (Double, String) -> Void) {
        _viewModel = StateObject(wrappedValue: RequestPaymentViewModel(amount: amount, onRequest: onRequest))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Request Amount")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        TextField("Amount (MON)", text: $viewModel.amount)
                            .padding()
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
                                    Text(String(format: "%.1f", amount))
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
                    
                    Button(action: {
                        viewModel.submitRequest()
                    }) {
                        Text("Request Payment")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(viewModel.isRequestEnabled ? Color.blue : Color.gray)
                            )
                            .padding(.horizontal)
                    }
                    .disabled(!viewModel.isRequestEnabled)
                    .padding(.bottom, 20)
                }
                .padding(.top, 20)
            }
            .contentShape(Rectangle()) // Make entire scroll view tappable
            .onTapGesture {
                hideKeyboard() // Dismiss keyboard when tapping anywhere
            }
            .navigationTitle("Request Payment")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
            )
        }
    }
} 