import SwiftUI
import AVFoundation

struct SendMonForm: View {
    @StateObject private var privyService = PrivyService.shared
    @State private var recipientAddress: String = ""
    @State private var amount: String = ""
    @State private var showMaxAmountWarning = false
    @State private var errorMessage = ""
    @State private var selectedFriend: ContactFriend? = nil  // Renamed to avoid ambiguity
    @State private var showingFriendPicker = false
    @State private var showingQRScanner = false
    @State private var sendMode: SendMode = .address // Default to address mode
    
    let onSend: (String, Double) -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // Gas buffer - leave at least this much MON for gas fees
    private let gasBuffer: Double = 0.01
    
    // Theme colors
    private var accentColor: Color { Color.blue }
    private var errorColor: Color { Color.red }
    private var backgroundColor: Color { colorScheme == .dark ? Color.black.opacity(0.6) : Color.white }
    private var secondaryBgColor: Color { colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1) }
    private var selectedColor: Color { Color.purple }
    
    private var maxAmount: Double {
        guard let balanceStr = privyService.balance else { return 0 }
        
        // Extract the numeric part of the balance string (e.g., "10.5 MON" -> 10.5)
        let components = balanceStr.components(separatedBy: " ")
        guard let amountStr = components.first,
              let balance = Double(amountStr) else {
            return 0
        }
        
        // Return max amount user can send (balance minus gas buffer)
        return max(0, balance - gasBuffer)
    }
    
    private var isAmountValid: Bool {
        guard let amountDouble = Double(amount) else { return false }
        return amountDouble > 0 && amountDouble <= maxAmount
    }
    
    private var effectiveRecipientAddress: String {
        if sendMode == .friend, let friend = selectedFriend {
            // In a real app, you'd get the wallet address from the friend object
            // For now, we'll simulate this with the username
            return "0x" + friend.username.dropFirst().data(using: .utf8)!.map { String(format: "%02x", $0) }.joined()
        } else {
            return recipientAddress
        }
    }
    
    private var isSendButtonEnabled: Bool {
        if sendMode == .address {
            return isAmountValid && !recipientAddress.isEmpty
        } else {
            return isAmountValid && selectedFriend != nil
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Balance Info Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Available Balance")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let balance = privyService.balance {
                            Text(balance)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(accentColor)
                        } else {
                            Text("Loading balance...")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                            Text("Maximum send amount: \(String(format: "%.5f", maxAmount)) MON")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(secondaryBgColor)
                    .cornerRadius(12)
                    
                    // Send Mode Selector
                    Picker("Send Mode", selection: $sendMode) {
                        Text("Address").tag(SendMode.address)
                        Text("Friend").tag(SendMode.friend)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    // Recipient Section (Address or Friend)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(sendMode == .address ? "Recipient Address" : "Send To Friend")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if sendMode == .address {
                            // Address input with QR scan option
                            HStack {
                                Image(systemName: "wallet.pass")
                                    .foregroundColor(.secondary)
                                
                    TextField("Enter wallet address", text: $recipientAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                                    .padding(10)
                                    .background(secondaryBgColor)
                                    .cornerRadius(8)
                                
                                Button(action: {
                                    showingQRScanner = true
                                }) {
                                    Image(systemName: "qrcode.viewfinder")
                                        .font(.system(size: 20))
                                        .foregroundColor(accentColor)
                                }
                            }
                        } else {
                            // Friend selection
                            Button(action: {
                                showingFriendPicker = true
                            }) {
                                HStack {
                                    if let friend = selectedFriend {
                                        // Selected friend display
                                        Circle()
                                            .fill(selectedColor.opacity(0.2))
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Image(systemName: friend.avatarName)
                                                    .font(.system(size: 18))
                                                    .foregroundColor(selectedColor)
                                            )
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(friend.name)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            
                                            Text(friend.username)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    } else {
                                        // No friend selected state
                                        Image(systemName: "person.crop.circle.badge.plus")
                                            .font(.system(size: 18))
                                            .foregroundColor(selectedColor)
                                        
                                        Text("Select Friend")
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(secondaryBgColor)
                                .cornerRadius(10)
                            }
                        }
                    }
                    
                    // Amount
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: "creditcard")
                                .foregroundColor(.secondary)
                            
                            TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                                .padding(10)
                                .background(secondaryBgColor)
                                .cornerRadius(8)
                                .onChange(of: amount) { newValue in
                                    validateAmount()
                                }
                            
                            Text("MON")
                                .foregroundColor(.secondary)
                                .padding(.trailing, 10)
                        }
                        
                        if !errorMessage.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(errorColor)
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(errorColor)
                            }
                            .padding(.top, 4)
                        }
                        
                        Button(action: {
                            amount = String(format: "%.5f", maxAmount)
                        }) {
                            HStack {
                                Image(systemName: "arrow.up.to.line")
                                Text("Use Maximum Amount")
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(accentColor.opacity(0.1))
                            .foregroundColor(accentColor)
                            .cornerRadius(8)
                        }
                        .disabled(maxAmount <= 0)
                        .padding(.top, 8)
                    }
                    
                    Spacer()
                    
                    // Send Button
                    Button(action: {
                        if let amountDouble = Double(amount), isAmountValid {
                            Task {
                                do {
                                    try await privyService.sendTransaction(amount: amountDouble, to: effectiveRecipientAddress)
                                } catch {
                                    print("Error sending transaction: \(error)")
                                }
                            }
                            dismiss()
                        }
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Send \(amount.isEmpty ? "MON" : "\(amount) MON")")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSendButtonEnabled ? accentColor : accentColor.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(15)
                    }
                    .disabled(!isSendButtonEnabled)
                }
                .padding()
            }
            .onAppear {
                recipientAddress = privyService.defaultRecipientAddress
                let defaultAmount = min(privyService.defaultAmount, maxAmount)
                amount = String(format: "%.2f", defaultAmount)
                validateAmount()
            }
            .navigationTitle("Send MON")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
            )
            .alert(isPresented: $showMaxAmountWarning) {
                Alert(
                    title: Text("Invalid Amount"),
                    message: Text("Please enter an amount that is greater than 0 and less than your maximum available balance (balance minus gas fee)."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showingFriendPicker) {
                NavigationView {
                    ContactFriendPickerView(
                        selectedFriend: $selectedFriend,
                        isPresented: $showingFriendPicker,
                        onSendRequest: { friend in
                            selectedFriend = friend
                            showingFriendPicker = false
                        }
                    )
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingQRScanner) {
                QRScannerView { result in
                    showingQRScanner = false
                    recipientAddress = result
                }
            }
        }
    }
    
    private func validateAmount() {
        guard !amount.isEmpty else {
            errorMessage = ""
            return
        }
        
        guard let amountDouble = Double(amount) else {
            errorMessage = "Please enter a valid number"
            return
        }
        
        if amountDouble <= 0 {
            errorMessage = "Amount must be greater than 0"
        } else if amountDouble > maxAmount {
            errorMessage = "Amount exceeds your available balance (including gas fee)"
        } else {
            errorMessage = ""
        }
    }
}

// MARK: - Supporting Models and Views

enum SendMode {
    case address
    case friend
}

// Friend Model - renamed to avoid ambiguity with the Friend struct from MerchantView
struct ContactFriend: Identifiable, Equatable {
    var id: String
    var name: String
    var username: String
    var avatarName: String
}

// FriendPickerView - reused but renamed for clarity
struct ContactFriendPickerView: View {
    @Binding var selectedFriend: ContactFriend?
    @Binding var isPresented: Bool
    @State private var searchText = ""
    let onSendRequest: (ContactFriend) -> Void
    
    @StateObject private var viewModel = ContactFriendsViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    private var surfaceColor: Color { colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1) }
    
    var filteredFriends: [ContactFriend] {
        if searchText.isEmpty {
            return viewModel.friends
        } else {
            return viewModel.friends.filter {
                $0.name.lowercased().contains(searchText.lowercased()) ||
                $0.username.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search friends", text: $searchText)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(surfaceColor)
            .cornerRadius(10)
            .padding()
            
            if filteredFriends.isEmpty {
                emptyFriendsView
            } else {
                // Friends list
                List {
                    ForEach(filteredFriends) { friend in
                        friendRow(friend: friend)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Select Friend")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    isPresented = false
                }
            }
        }
        .onAppear {
            viewModel.loadFriends()
        }
    }
    
    private var emptyFriendsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.5))
                .padding()
            
            if searchText.isEmpty {
                Text("No friends yet")
                    .font(.headline)
                
                Text("You haven't added any friends to send MON to")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("No matches found")
                    .font(.headline)
                
                Text("Try a different search term")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func friendRow(friend: ContactFriend) -> some View {
        Button(action: {
            selectedFriend = friend
            onSendRequest(friend)
        }) {
            HStack(spacing: 16) {
                // Avatar image
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: friend.avatarName)
                        .font(.system(size: 24))
                        .foregroundColor(.purple)
                }
                
                // Friend info
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.name)
                        .font(.headline)
                    
                    Text(friend.username)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selection indicator
                if selectedFriend?.id == friend.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.purple)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// FriendsViewModel - renamed to avoid conflicts
class ContactFriendsViewModel: ObservableObject {
    @Published var friends: [ContactFriend] = []
    
    func loadFriends() {
        // In a real app, this would load from your backend
        // For now, let's add some sample data
        self.friends = [
            ContactFriend(id: "1", name: "Alex Chen", username: "@alexc", avatarName: "person.crop.circle.fill"),
            ContactFriend(id: "2", name: "Sam Taylor", username: "@samtaylor", avatarName: "person.crop.circle.fill"),
            ContactFriend(id: "3", name: "Jordan Lee", username: "@jlee", avatarName: "person.crop.circle.fill"),
            ContactFriend(id: "4", name: "Casey Morgan", username: "@cmorg", avatarName: "person.crop.circle.fill"),
            ContactFriend(id: "5", name: "Taylor Swift", username: "@taylorswift", avatarName: "person.crop.circle.fill")
        ]
    }
}

#Preview {
    SendMonForm { recipientAddress, amount in
        print("Would send \(amount) MON to \(recipientAddress)")
    }
}
