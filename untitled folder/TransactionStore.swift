import Foundation
import SwiftData

@Model
final class TransactionRecord {
    @Attribute(.unique) var id: UUID
    var amount: Double
    var senderAddress: String
    var recipientAddress: String
    var note: String?
    var timestamp: Date
    var transactionHash: String
    var status: TransactionStatus
    
    init(
        id: UUID = UUID(),
        amount: Double,
        senderAddress: String,
        recipientAddress: String,
        note: String? = nil,
        timestamp: Date = Date(),
        transactionHash: String,
        status: TransactionStatus = .completed
    ) {
        self.id = id
        self.amount = amount
        self.senderAddress = senderAddress
        self.recipientAddress = recipientAddress
        self.note = note
        self.timestamp = timestamp
        self.transactionHash = transactionHash
        self.status = status
    }
}

enum TransactionStatus: String, Codable {
    case pending
    case completed
    case failed
} 