// MARK: - Models
enum AuthState {
    case notReady
    case unauthenticated
    case authenticated(User)
}

struct User {
    let id: String
    let email: String
}

enum AuthError: Error {
    case invalidCode
    case networkError
    case unknown
}

enum WalletError: Error {
    case creationFailed
    case providerNotInitialized
    case rpcError(String)
}

enum OTPFlowState {
    case initial
    case sourceNotSpecified
    case sendCodeFailure(Error)
    case sendingCode
    case awaitingCodeInput
    case submittingCode
    case incorrectCode
    case loginError(Error)
    case done
}

enum EmbeddedWalletState {
    case notConnected
    case connecting
    case connected(wallets: [Wallet])
}

struct Wallet {
    let address: String
}

// Add JSON-RPC response structure
struct JSONRPCResponse: Codable {
    let jsonrpc: String
    let result: String
    let id: Int
}

// Add JSON-RPC error response structure
struct JSONRPCErrorResponse: Codable {
    let jsonrpc: String
    let error: JSONRPCError
    let id: Int
}

struct JSONRPCError: Codable {
    let code: Int
    let message: String
}

// Add Transaction struct for the provider
struct Transaction: Codable {
    let to: String
    let value: String
    let from: String
}

import SwiftData
import Foundation

enum TransactionType: String, Codable {
    case sent = "Sent"
    case received = "Received"
}

enum TransactionStatus: String, Codable {
    case completed = "Completed"
    case pending = "Pending"
    case failed = "Failed"
}

@Model
final class PaymentTransaction {
    var isApproved: Bool
    var transactionHash: String?
    var amount: String?
    var sender: String?
    var recipient: String?
    var note: String?
    var timestamp: Date
    var type: TransactionType
    var status: TransactionStatus
    
    init(
        isApproved: Bool,
        transactionHash: String? = nil,
        amount: String? = nil,
        sender: String? = nil,
        recipient: String? = nil,
        note: String? = nil,
        timestamp: Date = Date(),
        type: TransactionType = .received,
        status: TransactionStatus = .completed
    ) {
        self.isApproved = isApproved
        self.transactionHash = transactionHash
        self.amount = amount
        self.sender = sender
        self.recipient = recipient
        self.note = note
        self.timestamp = timestamp
        self.type = type
        self.status = isApproved ? .completed : .failed
    }
    
    // Helper to create a transaction from a payment response message
    static func fromResponseMessage(_ message: String) -> PaymentTransaction {
        let components = message.split(separator: ":").map { String($0) }
        
        let isApproved = components.count > 1 && components[1] == "APPROVED"
        let transactionHash = components.count > 2 ? components[2] : nil
        let amount = components.count > 3 ? components[3] : nil
        let sender = components.count > 4 ? components[4] : nil
        let recipient = components.count > 5 ? components[5] : nil
        let note = components.count > 6 ? components[6] : nil
        
        // Determine if this is a sent or received transaction
        // This is a simplification - you might need more logic based on your app
        let type: TransactionType = .received
        
        return PaymentTransaction(
            isApproved: isApproved,
            transactionHash: transactionHash,
            amount: amount,
            sender: sender,
            recipient: recipient,
            note: note,
            type: type,
            status: isApproved ? .completed : .failed
        )
    }
    
    var title: String {
        return note ?? (type == .sent ? "Payment Sent" : "Payment Received")
    }
    
    var formattedAmount: String {
        let prefix = type == .sent ? "-" : "+"
        if let amountStr = amount {
            return "\(prefix)\(amountStr) MON"
        }
        return "\(prefix)0 MON"
    }
}
