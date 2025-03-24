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

// MARK: - Payment Request Models
struct PaymentRequestModel: Codable {
    let id: UUID
    let requesterId: String
    let friendId: String
    let amount: Decimal
    let note: String?
    let requestTimestamp: Date
    let status: RequestStatus
    let responseTimestamp: Date?
    let transactionHash: String?
    let expiresAt: Date
    let requester: RequesterInfo?
    
    struct RequesterInfo: Codable {
        let id: String
        let username: String
        let ethereumWallet: String
        
        enum CodingKeys: String, CodingKey {
            case id
            case username
            case ethereumWallet = "ethereum_wallet"
        }
    }
    
    // Joined data from user_profiles (optional as they come from joins)
    var requesterUsername: String?
    var requesterWallet: String?
    var friendUsername: String?
    var friendWallet: String?
    
    enum RequestStatus: String, Codable {
        case pending
        case approved
        case rejected
        case expired
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case friendId = "friend_id"
        case amount
        case note
        case requestTimestamp = "request_timestamp"
        case status
        case responseTimestamp = "response_timestamp"
        case transactionHash = "transaction_hash"
        case expiresAt = "expires_at"
        case requesterUsername = "requester_username"
        case requesterWallet = "requester_wallet"
        case friendUsername = "friend_username"
        case friendWallet = "friend_wallet"
        case requester
    }
    
    // Add custom decoding init to handle date strings
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode simple properties
        id = try container.decode(UUID.self, forKey: .id)
        requesterId = try container.decode(String.self, forKey: .requesterId)
        friendId = try container.decode(String.self, forKey: .friendId)
        amount = try container.decode(Decimal.self, forKey: .amount)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        status = try container.decode(RequestStatus.self, forKey: .status)
        transactionHash = try container.decodeIfPresent(String.self, forKey: .transactionHash)
        
        // Decode optional joined data
        requesterUsername = try container.decodeIfPresent(String.self, forKey: .requesterUsername)
        requesterWallet = try container.decodeIfPresent(String.self, forKey: .requesterWallet)
        friendUsername = try container.decodeIfPresent(String.self, forKey: .friendUsername)
        friendWallet = try container.decodeIfPresent(String.self, forKey: .friendWallet)
        
        // Decode dates with proper formatting
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let requestTimestampStr = try container.decodeIfPresent(String.self, forKey: .requestTimestamp),
           let date = dateFormatter.date(from: requestTimestampStr) {
            requestTimestamp = date
        } else {
            requestTimestamp = Date() // Fallback to current date if parsing fails
        }
        
        if let responseTimestampStr = try container.decodeIfPresent(String.self, forKey: .responseTimestamp),
           let date = dateFormatter.date(from: responseTimestampStr) {
            responseTimestamp = date
        } else {
            responseTimestamp = nil
        }
        
        if let expiresAtStr = try container.decodeIfPresent(String.self, forKey: .expiresAt),
           let date = dateFormatter.date(from: expiresAtStr) {
            expiresAt = date
        } else {
            expiresAt = Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? Date() // Default 24h expiry
        }
        
        requester = try container.decodeIfPresent(RequesterInfo.self, forKey: .requester)
    }
}

// Helper extension to convert between models
extension PaymentTransaction {
    static func fromRequest(_ request: PaymentRequestModel) -> PaymentTransaction {
        return PaymentTransaction(
            isApproved: request.status == .approved,
            transactionHash: request.transactionHash,
            amount: request.amount.description,
            sender: request.requesterWallet,
            recipient: request.friendWallet,
            note: request.note,
            timestamp: request.requestTimestamp,
            type: .sent,
            status: request.status == .approved ? .completed : 
                    request.status == .pending ? .pending : .failed
        )
    }
}

// Add this to your existing models.swift
struct CreatePaymentRequestBody: Codable {
    let friendId: String
    let amount: Decimal
    let note: String?
    
    enum CodingKeys: String, CodingKey {
        case friendId = "friend_id"
        case amount
        case note
    }
}

// Response model for created payment request
struct PaymentRequestResponse: Codable {
    let id: UUID
    let requesterId: String
    let friendId: String
    let amount: Decimal
    let note: String?
    let requestTimestamp: String
    let status: String
    let expiresAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case friendId = "friend_id"
        case amount
        case note
        case requestTimestamp = "request_timestamp"
        case status
        case expiresAt = "expires_at"
    }
}

struct UserProfile: Codable {
    let id: String
    let email: String?
    let twitter: String?
    let username: String
    let updatedAt: String
    let createdAt: String
    let ethereumWallet: String?
    let solanaWallet: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case twitter
        case username
        case updatedAt = "updated_at"
        case createdAt = "created_at"
        case ethereumWallet = "ethereum_wallet"
        case solanaWallet = "solana_wallet"
    }
}

// Add this to your models.swift file
struct Friend: Identifiable {
    let id: String
    let name: String
    let username: String
    let avatarName: String
    let ethereumWallet: String?
}

