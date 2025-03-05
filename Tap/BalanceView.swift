import SwiftUI

struct BalanceView: View {
    @StateObject private var privyService = PrivyService.shared
    @State private var isRefreshing = false
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Your Wallet")
                .font(.headline)
            
            if let address = privyService.walletAddress {
                VStack(spacing: 4) {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    if let balance = privyService.balance {
                        HStack(spacing: 8) {
                            Text(balance)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if isRefreshing {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .rotationEffect(.degrees(rotation))
                                    .onAppear {
                                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                            rotation = 360
                                        }
                                    }
                            }
                        }
                    } else {
                        Text("Fetching balance...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("Connecting wallet...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
        .refreshable {
            await refreshBalance()
        }
        .task {
            // Ensure wallet is connected before fetching balance
            if privyService.walletAddress != nil {
                if case .notConnected = privyService.embeddedWalletState {
                    print("Connecting wallet before fetching balance...")
                    await privyService.connectWallet()
                }
                await privyService.fetchBalance()
            }
        }
    }
    
    private func refreshBalance() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        // Add a small delay to ensure network has processed any pending transactions
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000) // 1 second
        
        // Ensure wallet is connected on manual refresh
        if case .notConnected = privyService.embeddedWalletState {
            print("Connecting wallet before refreshing balance...")
            await privyService.connectWallet()
        }
        
        await privyService.fetchBalance()
    }
}

#Preview {
    BalanceView()
} 