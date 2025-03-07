import SwiftUI
import SwiftData

struct TransactionHistoryView: View {
    @Query(sort: \PaymentTransaction.timestamp, order: .reverse) private var transactions: [PaymentTransaction]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var filterType: TransactionType?
    
    var filteredTransactions: [PaymentTransaction] {
        if let filterType = filterType {
            return transactions.filter { $0.type == filterType }
        }
        return transactions
    }
    
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
                        self.errorMessage = nil
                        self.isLoading = false
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.top)
                }
                .padding()
            } else if filteredTransactions.isEmpty {
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
                    ForEach(filteredTransactions) { transaction in
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
    }
    
    private func filterTransactions(by type: TransactionType?) {
        filterType = type
    }
}

struct TransactionRow: View {
    let transaction: PaymentTransaction
    
    var body: some View {
        HStack {
            Image(systemName: transaction.type == .sent ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundColor(transaction.type == .sent ? .red : .green)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.headline)
                Text(transaction.timestamp, style: .date)
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

#Preview {
    NavigationView {
        TransactionHistoryView()
    }
} 