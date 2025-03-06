import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @Binding var isLoggedIn: Bool
    @Environment(\.dismiss) private var dismiss
    
    init(privyService: PrivyService, bleService: BLEService, isLoggedIn: Binding<Bool>) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(privyService: privyService, bleService: bleService))
        _isLoggedIn = isLoggedIn
    }
    
    var body: some View {
        List {
            Section {
                NavigationLink {
                    AccountSettingsView()
                } label: {
                    Label("Account", systemImage: "person.circle")
                }
                
                NavigationLink {
                    WalletSettingsView()
                } label: {
                    Label("Wallet", systemImage: "wallet.pass")
                }
                
                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    Label("Notifications", systemImage: "bell")
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
}

struct AccountSettingsView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    ProfileView()
                } label: {
                    Label("Profile", systemImage: "person.text.rectangle")
                }
                
                NavigationLink {
                    SecurityView()
                } label: {
                    Label("Security", systemImage: "lock.shield")
                }
            }
        }
        .navigationTitle("Account")
    }
}

struct WalletSettingsView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    NetworkSettingsView()
                } label: {
                    Label("Network", systemImage: "network")
                }
                
                NavigationLink {
                    TransactionHistoryView()
                } label: {
                    Label("Transaction History", systemImage: "clock.arrow.circlepath")
                }
            }
        }
        .navigationTitle("Wallet")
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
struct ProfileView: View {
    var body: some View {
        Text("Profile Settings")
            .navigationTitle("Profile")
    }
}

struct SecurityView: View {
    var body: some View {
        Text("Security Settings")
            .navigationTitle("Security")
    }
}

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