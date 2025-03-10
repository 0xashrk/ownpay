import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @Binding var isLoggedIn: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var addressCopied = false
    
    init(privyService: PrivyService, bleService: BLEService, isLoggedIn: Binding<Bool>) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel.shared)
        _isLoggedIn = isLoggedIn
    }
    
    var body: some View {
        List {
            Section(header: Text("Wallet")) {
                Button(action: {
                    copyWalletAddress()
                }) {
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Text(viewModel.privyService.walletAddress ?? "Not connected")
                                .foregroundColor(.secondary)
                                .font(.callout)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            if addressCopied {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            } else {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink {
                    TransactionHistoryView()
                } label: {
                    Label("Transaction History", systemImage: "clock.arrow.circlepath")
                }
            }
            
            Section(header: Text("Wallet Mode")) {
                ForEach(WalletMode.allCases, id: \.self) { mode in
                    Button(action: {
                        viewModel.selectedMode = mode
                        print("Settings View: Mode changed to \(mode)")
                    }) {
                        HStack {
                            Image(systemName: iconForMode(mode))
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            Text(titleForMode(mode))
                            
                            Spacer()
                            
                            if viewModel.selectedMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            
            Section {
                Button(role: .destructive) {
                    Task {
                        await viewModel.logout()
                        isLoggedIn = false
                        dismiss()
                    }
                } label: {
                    HStack {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                        Spacer()
                        if viewModel.isLoggingOut {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .red))
                        }
                    }
                }
                .disabled(viewModel.isLoggingOut)
            }
        }
        .navigationTitle("Settings")
        .alert("Logout Error", isPresented: .constant(viewModel.logoutError != nil)) {
            Button("OK") {
                viewModel.logoutError = nil
            }
        } message: {
            if let error = viewModel.logoutError {
                Text(error)
            }
        }
    }
    
    private func copyWalletAddress() {
        guard let address = viewModel.privyService.walletAddress else { return }
        
        #if os(iOS)
        UIPasteboard.general.string = address
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(address, forType: .string)
        #endif
        
        // Show copied indicator
        withAnimation {
            addressCopied = true
        }
        
        // Reset copied status after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                addressCopied = false
            }
        }
    }
    
    private func iconForMode(_ mode: WalletMode) -> String {
        switch mode {
        case .customer:
            return "person.fill"
        case .merchant:
            return "storefront.fill"
        case .faucet:
            return "drop.fill"
        }
    }
    
    private func titleForMode(_ mode: WalletMode) -> String {
        switch mode {
        case .customer:
            return "Customer Mode"
        case .merchant:
            return "Merchant Mode"
        case .faucet:
            return "Faucet Mode"
        }
    }
}

struct NotificationSettingsView: View {
    @State private var paymentNotifications = true
    @State private var transactionNotifications = true
    @State private var marketingNotifications = false
    
    var body: some View {
        List {
            Section {
                Toggle("Payment Notifications", isOn: $paymentNotifications)
                Toggle("Transaction Updates", isOn: $transactionNotifications)
            } header: {
                Text("Transaction Notifications")
            }
            
            Section {
                Toggle("Marketing Updates", isOn: $marketingNotifications)
            } header: {
                Text("Marketing")
            }
        }
        .navigationTitle("Notifications")
    }
}

// Placeholder views for future implementation
struct NetworkSettingsView: View {
    var body: some View {
        Text("Network Settings")
            .navigationTitle("Network")
    }
}

// TransactionHistoryView has been moved to its own file

#Preview {
    NavigationView {
        SettingsView(
            privyService: PrivyService.shared,
            bleService: BLEService(),
            isLoggedIn: .constant(true)
        )
    }
} 