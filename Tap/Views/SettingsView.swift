import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @Binding var isLoggedIn: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToModes = false
    @State private var showingUsernameEditor = false
    @State private var localUsername: String? = nil
    
    init(privyService: PrivyService, bleService: BLEService, isLoggedIn: Binding<Bool>) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel.shared)
        _isLoggedIn = isLoggedIn
    }
    
    var body: some View {
        List {
            // Username row - completely standalone with no section
            VStack(spacing: 16) {
                // Centered username with neon effect
                if let username = localUsername {
                    Text(username)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(Color(red: 0.3, green: 0.8, blue: 1.0))
                        .shadow(color: Color(red: 0.3, green: 0.8, blue: 1.0).opacity(0.8), radius: 8, x: 0, y: 0)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                } else if viewModel.userProfileService.isLoadingProfile {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Username")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(Color.gray)
                        .frame(maxWidth: .infinity)
                }
                
                // Edit Profile button - cyberpunk style
                Button(action: {
                    showingUsernameEditor = true
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16))
                        
                        Text("Edit Profile")
                            .font(.system(size: 18, weight: .medium))
                    }
                    .foregroundColor(Color(red: 0.3, green: 0.8, blue: 1.0))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(red: 0.3, green: 0.8, blue: 1.0), lineWidth: 0.3)
                    )
                }
                .padding(.top, 8)
                .disabled(viewModel.userProfileService.isLoadingProfile)
            }
            .padding(.vertical, 25)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            
            if let error = viewModel.userProfileService.profileError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
            
            Section(header: Text("WALLET").foregroundColor(.gray).font(.caption)) {
                Button(action: {
                    viewModel.copyWalletAddress()
                }) {
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Text(viewModel.privyService.walletAddress ?? "Not connected")
                                .foregroundColor(.secondary)
                                .font(.callout)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            if viewModel.addressCopied {
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
            
//            Section(header: Text("SETTINGS").foregroundColor(.gray).font(.caption)) {
//                // Display current wallet mode
//                HStack {
//                    Image(systemName: viewModel.iconForMode(viewModel.selectedMode))
//                        .foregroundColor(.blue)
//                        .frame(width: 30)
//                    
//                    Text("Current Mode: \(viewModel.titleForMode(viewModel.selectedMode))")
//                    
//                    Spacer()
//                }
//                
//                // Simple button that shows password prompt
//                Button(action: {
//                    viewModel.showingPasswordPrompt = true
//                }) {
//                    HStack {
//                        Image(systemName: "lock.shield")
//                            .foregroundColor(.blue)
//                            .frame(width: 30)
//                        
//                        Text("Change Wallet Mode")
//                        
//                        Spacer()
//                        
//                        Image(systemName: "chevron.right")
//                            .foregroundColor(.gray)
//                            .font(.caption)
//                    }
//                }
//            }
            
//            Section(header: Text("API Connection Test")) {
//                Button(action: {
//                    viewModel.testApiConnection()
//                }) {
//                    HStack {
//                        Image(systemName: "network")
//                            .foregroundColor(.blue)
//                            .frame(width: 30)
//                        
//                        Text("Test Backend Connection")
//                        
//                        Spacer()
//                        
//                        if viewModel.isTestingApi {
//                            ProgressView()
//                                .progressViewStyle(CircularProgressViewStyle())
//                        } else if let result = viewModel.apiTestResult {
//                            Text(result)
//                                .font(.caption)
//                                .foregroundColor(.green)
//                        } else if let error = viewModel.apiTestError {
//                            Text(error)
//                                .font(.caption)
//                                .foregroundColor(.red)
//                        }
//                    }
//                }
//                .disabled(viewModel.isTestingApi)
//            }
            
            // Add spacing after the settings section
            Divider()
                .frame(height: 20)
                .opacity(0)

            // Logout section with improved visual separation
            Section {
                Button(role: .destructive) {
                    Task {
                        await viewModel.logout()
                        isLoggedIn = false
                        dismiss()
                    }
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                            .frame(width: 30)
                        
                        Text("Logout")
                            .foregroundColor(.red)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        if viewModel.isLoggingOut {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .red))
                        }
                    }
                    .padding(.vertical, 10)
                }
                .disabled(viewModel.isLoggingOut)
            }
            .listSectionSeparator(.hidden, edges: .top)
        }
        .refreshable {
            await viewModel.userProfileService.fetchUserProfile(silently: false, bypassRateLimit: true, forceRefresh: true)
            
            // This is the key step - explicitly update the local state
            await MainActor.run {
                print("UI Refresh: Old value: \(localUsername ?? "nil"), New value: \(viewModel.userProfileService.storedUsername ?? "nil")")
                localUsername = viewModel.userProfileService.storedUsername
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Initialize with current value
            localUsername = viewModel.userProfileService.storedUsername
            
            // Fetch user profile when view appears
            Task {
                await viewModel.refreshUserProfile()
                
                // Force update of local state
                await MainActor.run {
                    localUsername = viewModel.userProfileService.storedUsername
                }
            }
        }
        // Password prompt
        .alert("Enter Admin Password", isPresented: $viewModel.showingPasswordPrompt) {
            SecureField("Password", text: $viewModel.enteredPassword)
                .keyboardType(.default)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            Button("Cancel", role: .cancel) {
                viewModel.resetPasswordState()
            }
            
            Button("Verify") {
                if viewModel.verifyPassword(viewModel.enteredPassword) {
                    navigateToModes = true
                    viewModel.resetPasswordState()
                }
            }
        } message: {
            if viewModel.passwordError {
                Text("Incorrect password. Please try again.")
            } else {
                Text("Enter admin password to access wallet modes.")
            }
        }
        // Logout error
        .alert("Logout Error", isPresented: .constant(viewModel.logoutError != nil)) {
            Button("OK") {
                viewModel.logoutError = nil
            }
        } message: {
            if let error = viewModel.logoutError {
                Text(error)
            }
        }
        // Navigation to modes view
        .background(
            NavigationLink(destination: WalletModesView(viewModel: viewModel), isActive: $navigateToModes) {
                EmptyView()
            }
            .hidden()
        )
        .listStyle(PlainListStyle())
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .sheet(isPresented: $showingUsernameEditor) {
            UsernameEditorSheet { newUsername in
                // Immediately update the local username for instant UI feedback
                localUsername = newUsername
                
                // Then refresh from backend to ensure everything is consistent
                Task {
                    await viewModel.refreshUserProfile()
                    
                    // Make sure the UI state stays in sync with the refreshed data
                    await MainActor.run {
                        localUsername = viewModel.userProfileService.storedUsername
                    }
                }
            }
        }
    }
}

// Wallet modes selection view
struct WalletModesView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        List {
            ForEach(WalletMode.allCases, id: \.self) { mode in
                Button(action: {
                    viewModel.selectedMode = mode
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: viewModel.iconForMode(mode))
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        
                        Text(viewModel.titleForMode(mode))
                        
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
        .navigationTitle("Select Wallet Mode")
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
