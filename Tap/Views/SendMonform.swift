import SwiftUI
import AVFoundation
import SwiftData

struct SendMonForm: View {
    @StateObject private var privyService = PrivyService.shared
    @StateObject private var friendsViewModel = FriendsViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var recipientAddress: String = ""
    @State private var amount: String = ""
    @State private var showMaxAmountWarning = false
    @State private var errorMessage = ""
    @State private var selectedFriend: Friend? = nil
    @State private var showingFriendPicker = false
    @State private var showingQRScanner = false
    @State private var sendMode: SendMode = .address
    @State private var isSubmitting = false
    @State private var showingConfirmation = false
    
    let onSend: (String, Double) -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // Gas buffer - leave at least this much MON for gas fees
    private let gasBuffer: Double = 0.01
    
    // Theme colors
    private var primaryColor: Color { Color.blue }
    private var secondaryColor: Color { Color.purple }
    private var errorColor: Color { Color.red }
    private var surfaceColor: Color { colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1) }
    private var backgroundColor: Color { colorScheme == .dark ? Color.black.opacity(0.6) : Color.white }
    
    private var maxAmount: Double {
        guard let balanceStr = privyService.balance else { return 0 }
        let components = balanceStr.components(separatedBy: " ")
        guard let amountStr = components.first,
              let balance = Double(amountStr) else {
            return 0
        }
        return max(0, balance - gasBuffer)
    }
    
    private var isAmountValid: Bool {
        guard let amountDouble = Double(amount) else { return false }
        return amountDouble > 0 && amountDouble <= maxAmount
    }
    
    private var effectiveRecipientAddress: String {
        if sendMode == .friend, let friend = selectedFriend {
            // Use the actual Ethereum wallet address instead of generating a dummy one
            return friend.ethereumWallet ?? recipientAddress
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
    
    private var formattedAmount: String {
        guard let amountDouble = Double(amount), amountDouble > 0 else {
            return "0.00 MON"
        }
        return "\(String(format: "%.2f", amountDouble)) MON"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                ScrollView {
                VStack(spacing: 24) {
                        // Balance Card
                        balanceCard
                        
                        // Send To Section
                        sendToSection
                        
                        // Amount Section
                        amountSection
                        
                        // Summary Card (only shown when both fields are valid)
//                        if isSendButtonEnabled {
//                            summaryCard
//                                .transition(.opacity)
//                        }
                        
                        Spacer(minLength: 30)
                        
                        // Send Button
                        sendButton
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("Send MON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                            dismiss()
                    }
                }
            }
                        .onAppear {
                            recipientAddress = privyService.defaultRecipientAddress
                let defaultAmount = min(privyService.defaultAmount, maxAmount)
                amount = String(format: "%.2f", defaultAmount)
                validateAmount()
                friendsViewModel.loadFriends()
            }
            .alert(isPresented: $showMaxAmountWarning) {
                Alert(
                    title: Text("Invalid Amount"),
                    message: Text("Please enter an amount that is greater than 0 and less than your maximum available balance (balance minus gas fee)."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showingFriendPicker) {
                NavigationView {
                    FriendPickerView(
                        selectedFriend: $selectedFriend,
                        isPresented: $showingFriendPicker,
                        mode: .send
                    ) { friend in
                        selectedFriend = friend
                        showingFriendPicker = false
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingQRScanner) {
                QRScannerView { result in
                    showingQRScanner = false
                    recipientAddress = result
                }
            }
            .overlay {
                if showingConfirmation {
                    transactionConfirmationView
                }
            }
        }
    }
    
    // MARK: - UI Components
    
    private var balanceCard: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available Balance")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let balance = privyService.balance {
                        Text(balance)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(primaryColor)
                    } else {
                        Text("Loading balance...")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 28))
                    .foregroundColor(primaryColor.opacity(0.7))
            }
            
            Divider()
                .padding(.vertical, 5)
            
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                
                Text("Maximum send amount: \(String(format: "%.5f", maxAmount)) MON")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding()
        .background(surfaceColor)
        .cornerRadius(16)
    }
    
    private var sendToSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Send To")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Mode Selector
            HStack(spacing: 10) {
                // Address button
                Button(action: { sendMode = .address }) {
                    VStack(spacing: 8) {
                        Image(systemName: "wallet.pass")
                            .font(.system(size: 24))
                        
                        Text("Address")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(sendMode == .address ? primaryColor.opacity(0.2) : surfaceColor)
                    .foregroundColor(sendMode == .address ? primaryColor : .gray)
                    .cornerRadius(12)
                }
                
                // Friend button
                Button(action: { sendMode = .friend }) {
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 24))
                        
                        Text("Friend")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(sendMode == .friend ? secondaryColor.opacity(0.2) : surfaceColor)
                    .foregroundColor(sendMode == .friend ? secondaryColor : .gray)
                    .cornerRadius(12)
                }
            }
            
            if sendMode == .address {
                // Address Field
                VStack(spacing: 8) {
                    HStack {
                        TextField("Enter wallet address", text: $recipientAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding(.vertical, 12)
                        
                        Spacer()
                        
                        Button(action: {
                            showingQRScanner = true
                        }) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 20))
                                .foregroundColor(primaryColor)
                                .frame(width: 40, height: 40)
                                .background(primaryColor.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 12)
                    .background(surfaceColor)
                    .cornerRadius(12)
                    
                    if !recipientAddress.isEmpty {
                        HStack {
                            Text("Address looks good")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Spacer()
                        }
                        .padding(.leading, 5)
                    }
                }
            } else {
                // Friend Selection
                Button(action: {
                    showingFriendPicker = true
                }) {
                    HStack {
                        if let friend = selectedFriend {
                            // Selected friend
                            ZStack {
                                Circle()
                                    .fill(secondaryColor.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: friend.avatarName)
                                    .font(.system(size: 20))
                                    .foregroundColor(secondaryColor)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.name)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Text(friend.username)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(secondaryColor)
                                .padding(.trailing, 5)
                        } else {
                            // No friend selected
                            ZStack {
                                Circle()
                                    .fill(surfaceColor)
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 18))
                                    .foregroundColor(secondaryColor)
                            }
                            
                            Text("Select a Friend")
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .padding(.trailing, 5)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(surfaceColor)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amount")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 10) {
                // Amount Input
                HStack(spacing: 8) {
                    TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 22, weight: .medium))
                        .padding(.vertical, 12)
                        .onChange(of: amount) { newValue in
                            validateAmount()
                        }
                    
                    Text("MON")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                    
                    Spacer()
                    
                    // Max amount button
                    Button(action: {
                        amount = String(format: "%.2f", maxAmount)
                    }) {
                        Text("MAX")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(primaryColor)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .disabled(maxAmount <= 0)
                }
                .padding(.horizontal, 12)
                .background(surfaceColor)
                .cornerRadius(12)
                
                // Error message
                if !errorMessage.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(errorColor)
                        
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(errorColor)
                        
                        Spacer()
                    }
                    .padding(.leading, 5)
                }
                
                // Value equivalents could go here (e.g., USD value)
                if isAmountValid, let amountValue = Double(amount), amountValue > 0 {
                    HStack {
                        Text("≈ $\(String(format: "%.2f", amountValue * 1.21)) USD")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.leading, 5)
                }
            }
        }
    }
    
    private var summaryCard: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Transaction Summary")
                    .font(.headline)
                
                Spacer()
            }
            
            Divider()
            
            Group {
                // Recipient
                HStack(alignment: .top) {
                    Text("Recipient:")
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    
                    if sendMode == .friend, let friend = selectedFriend {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(friend.name)
                                .fontWeight(.medium)
                            
                            Text(friend.username)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(effectiveRecipientAddress.prefix(12) + "..." + effectiveRecipientAddress.suffix(8))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack(alignment: .leading) {
                            Text(effectiveRecipientAddress.prefix(12) + "..." + effectiveRecipientAddress.suffix(8))
                                .fontWeight(.medium)
                        }
                    }
                    
                    Spacer()
                }
                
                // Amount
                HStack {
                    Text("Amount:")
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    
                    Text(formattedAmount)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                
                // Network fee
                HStack {
                    Text("Fee:")
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    
                    Text("≈ 0.001 MON")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 5)
        }
        .padding()
        .background(surfaceColor)
        .cornerRadius(16)
    }
    
    private var sendButton: some View {
        Button(action: {
            if let amountDouble = Double(amount), isAmountValid {
                withAnimation {
                    isSubmitting = true
                    showingConfirmation = true
                }
                
                Task {
                    do {
                        // Get the actual transaction hash from sendTransaction
                        let transactionHash = try await privyService.sendTransaction(amount: amountDouble, to: effectiveRecipientAddress)
                        
                        // Record the transaction with the real hash
                        recordTransaction(
                            amount: amountDouble,
                            recipient: effectiveRecipientAddress,
                            hash: transactionHash  // Use the real transaction hash
                        )
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                showingConfirmation = false
                                isSubmitting = false
                                dismiss()
                            }
                        }
                    } catch {
                        print("Error sending transaction: \(error)")
                        isSubmitting = false
                        showingConfirmation = false
                        // You might want to show an error alert here
                    }
                }
            }
        }) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.trailing, 8)
                } else {
                    Image(systemName: "paperplane.fill")
                        .padding(.trailing, 8)
                }
                
                Text(isSubmitting ? "Sending..." : "Send \(formattedAmount)")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSendButtonEnabled && !isSubmitting ? primaryColor : primaryColor.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .disabled(!isSendButtonEnabled || isSubmitting)
    }
    
    private var transactionConfirmationView: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: primaryColor))
                        .scaleEffect(1.5)
                    
                    Text("Sending Transaction")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.top, 20)
                    
                    Text("Your MON is on its way...")
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Transaction Complete!")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
            .padding(30)
            .background(backgroundColor)
            .cornerRadius(20)
            .shadow(radius: 10)
        }
        .transition(.opacity)
    }
    
    // MARK: - Helper Methods
    
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
    
    private func recordTransaction(amount: Double, recipient: String, hash: String) {
        let transaction = PaymentTransaction(
            isApproved: true,
            transactionHash: hash,
            amount: String(amount),
            sender: privyService.walletAddress,
            recipient: recipient,
            note: nil,
            timestamp: Date(),
            type: .sent,
            status: .completed
        )
        
        // Add to SwiftData
        modelContext.insert(transaction)
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving transaction: \(error)")
        }
    }
}

// MARK: - Supporting Models and Views

enum SendMode {
    case address
    case friend
}

#Preview {
    SendMonForm { recipientAddress, amount in
        print("Would send \(amount) MON to \(recipientAddress)")
    }
}
