import Foundation
import SwiftData

class TransactionStore {
    static func saveTransaction(
        context: ModelContext,
        amount: Double,
        senderAddress: String,
        recipientAddress: String,
        note: String? = nil,
        transactionHash: String,
        status: TransactionStatus = .completed
    ) {
        let transaction = TransactionRecord(
            amount: amount,
            senderAddress: senderAddress,
            recipientAddress: recipientAddress,
            note: note,
            transactionHash: transactionHash,
            status: status
        )
        
        context.insert(transaction)
        
        do {
            try context.save()
        } catch {
            print("Failed to save transaction: \(error.localizedDescription)")
        }
    }
} 