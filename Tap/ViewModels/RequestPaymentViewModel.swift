import Foundation
import SwiftUI

class RequestPaymentViewModel: ObservableObject {
    @Published var amount: String
    @Published var note: String = ""
    private let onRequest: (Double, String) -> Void
    
    let quickPaymentAmounts = [0.1, 0.5, 1.0, 5.0]
    
    init(amount: Binding<String>, onRequest: @escaping (Double, String) -> Void) {
        self._amount = Published(initialValue: amount.wrappedValue)
        self.onRequest = onRequest
    }
    
    var isRequestEnabled: Bool {
        !amount.isEmpty
    }
    
    func submitRequest() {
        if let amountDouble = Double(amount) {
            onRequest(amountDouble, note)
        }
    }
    
    func setQuickPaymentAmount(_ amount: Double) {
        self.amount = String(format: "%.2f", amount)
    }
} 