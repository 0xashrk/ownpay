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