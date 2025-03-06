import SwiftUI

struct TransactionHistoryView: View {
    @State private var transactions: [WalletTransaction] = WalletTransaction.sampleData
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .padding()
            } else if let errorMessage = errorMessage {
                VStack {
                    Text("Error loading transactions")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .foregroundColor(.secondary)
                    Button("Try Again") {
                        loadTransactions()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.top)
                }
                .padding()
            } else if transactions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No Transactions")
                        .font(.headline)
                    Text("You haven't made any transactions yet.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List {
                    ForEach(transactions) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                }
            }
        }
        .navigationTitle("Transaction History")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("All", action: { filterTransactions(by: nil) })
                    Button("Sent", action: { filterTransactions(by: .sent) })
                    Button("Received", action: { filterTransactions(by: .received) })
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .onAppear {
            loadTransactions()
        }
    }
    
    private func loadTransactions() {
        isLoading = true
        errorMessage = nil
        
        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // In a real app, you would fetch transactions from a service
            transactions = WalletTransaction.sampleData
            isLoading = false
        }
    }
    
    private func filterTransactions(by type: TransactionType?) {
        if let type = type {
            transactions = WalletTransaction.sampleData.filter { $0.type == type }
        } else {
            transactions = WalletTransaction.sampleData
        }
    }
}

struct TransactionRow: View {
    let transaction: WalletTransaction
    
    var body: some View {
        HStack {
            Image(systemName: transaction.type == .sent ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundColor(transaction.type == .sent ? .red : .green)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.headline)
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.formattedAmount)
                    .font(.headline)
                    .foregroundColor(transaction.type == .sent ? .red : .green)
                Text(transaction.status.rawValue)
                    .font(.caption)
                    .padding(4)
                    .background(
                        transaction.status == .completed ? Color.green.opacity(0.2) :
                        transaction.status == .pending ? Color.orange.opacity(0.2) :
                        Color.red.opacity(0.2)
                    )
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct WalletTransaction: Identifiable {
    let id = UUID()
    let title: String
    let amount: Double
    let date: Date
    let type: TransactionType
    let status: TransactionStatus
    
    var formattedAmount: String {
        let prefix = type == .sent ? "-" : "+"
        return "\(prefix)$\(String(format: "%.2f", amount))"
    }
    
    static var sampleData: [WalletTransaction] {
        [
            WalletTransaction(
                title: "Payment to John",
                amount: 50.0,
                date: Date().addingTimeInterval(-86400),
                type: .sent,
                status: .completed
            ),
            WalletTransaction(
                title: "Received from Sarah",
                amount: 25.0,
                date: Date().addingTimeInterval(-172800),
                type: .received,
                status: .completed
            ),
            WalletTransaction(
                title: "Gas fee refund",
                amount: 0.01,
                date: Date().addingTimeInterval(-259200),
                type: .received,
                status: .completed
            ),
            WalletTransaction(
                title: "NFT Purchase",
                amount: 0.5,
                date: Date().addingTimeInterval(-432000),
                type: .sent,
                status: .pending
            ),
            WalletTransaction(
                title: "Swap ETH to USDC",
                amount: 100.0,
                date: Date().addingTimeInterval(-518400),
                type: .sent,
                status: .failed
            )
        ]
    }
}

enum TransactionType {
    case sent
    case received
}

enum TransactionStatus: String {
    case completed = "Completed"
    case pending = "Pending"
    case failed = "Failed"
}

#Preview {
    NavigationView {
        TransactionHistoryView()
    }
} 