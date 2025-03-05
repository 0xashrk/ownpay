import SwiftUI

struct RequestPaymentFormView: View {
    @StateObject private var viewModel: RequestPaymentViewModel
    @Environment(\.dismiss) var dismiss
    
    init(amount: Binding<String>, onRequest: @escaping (Double) -> Void) {
        _viewModel = StateObject(wrappedValue: RequestPaymentViewModel(amount: amount, onRequest: onRequest))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Request Amount")) {
                    TextField("Amount (MON)", text: $viewModel.amount)
                        .keyboardType(.decimalPad)
                    
                    VStack(spacing: 8) {
                        Text("Quick Amounts")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            ForEach(viewModel.quickPaymentAmounts, id: \.self) { amount in
                                Button(action: {
                                    viewModel.setQuickPaymentAmount(amount)
                                }) {
                                    Text(String(format: "%.1f", amount))
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.blue.opacity(0.8))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.blue, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Request Payment")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Request") {
                    viewModel.submitRequest()
                }
                .disabled(!viewModel.isRequestEnabled)
            )
        }
    }
} 