import Foundation
import SwiftUI

class RequestPaymentViewModel: ObservableObject {
    @Published var amount: String
    private let onRequest: (Double) -> Void
    
    init(amount: Binding<String>, onRequest: @escaping (Double) -> Void) {
        self._amount = Published(initialValue: amount.wrappedValue)
        self.onRequest = onRequest
    }
    
    var isRequestEnabled: Bool {
        !amount.isEmpty
    }
    
    func submitRequest() {
        if let amountDouble = Double(amount) {
            onRequest(amountDouble)
        }
    }
} 