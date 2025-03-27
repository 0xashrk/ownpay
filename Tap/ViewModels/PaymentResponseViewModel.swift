import Foundation
import SwiftUI

class PaymentResponseViewModel: ObservableObject {
    @Published var message: String
    
    // Parse transaction details from the message
    private var components: [String] {
        message.split(separator: ":").map { String($0) }
    }
    
    var isApproved: Bool {
        components.count > 1 && (components[1] == "APPROVED" || components[1] == "SENT")
    }
    
    var statusText: String {
        isApproved ? "Payment Sent" : "Payment Declined"
    }
    
    var iconName: String {
        isApproved ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
    
    var statusColor: Color {
        isApproved ? .green : .red
    }
    
    var transactionHash: String? {
        components.count > 2 ? components[2] : nil
    }
    
    var amount: String? {
        components.count > 3 ? components[3] : nil
    }
    
    var sender: String? {
        components.count > 4 ? components[4] : nil
    }
    
    var recipient: String? {
        components.count > 5 ? components[5] : nil
    }
    
    var note: String? {
        components.count > 6 ? components[6] : nil
    }
    
    var hasTransactionDetails: Bool {
        transactionHash != nil && amount != nil
    }
    
    init(message: String) {
        self.message = message
    }
} 
