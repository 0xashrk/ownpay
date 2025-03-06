import Foundation
import SwiftUICore

class PaymentResponseViewModel: ObservableObject {
    @Published var message: String
    
    var isApproved: Bool {
        message.contains("APPROVED")
    }
    
    var statusText: String {
        isApproved ? "Payment Approved" : "Payment Declined"
    }
    
    var iconName: String {
        isApproved ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
    
    var statusColor: Color {
        isApproved ? .green : .red
    }
    
    init(message: String) {
        self.message = message
    }
} 
