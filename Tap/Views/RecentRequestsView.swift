import SwiftUI

struct RecentRequestsView: View {
    @ObservedObject var viewModel: MerchantViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerSection
            
            if viewModel.isRecentRequestsExpanded {
                requestsList
            }
        }
    }
    
    private var headerSection: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.isRecentRequestsExpanded.toggle()
            }
        }) {
            HStack {
                Text("Recent Requests")
                    .font(.headline)
                Spacer()
                Image(systemName: viewModel.isRecentRequestsExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .foregroundColor(.secondary)
                    .imageScale(.medium)
            }
//            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
    
    private var requestsList: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if viewModel.recentRequests.isEmpty {
                Text("No pending requests")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.recentRequests, id: \.id) { request in
                            RequestRow(request: request, viewModel: viewModel)
                        }
                    }
//                    .padding(.horizontal)
                }
            }
        }
    }
}

struct RequestRow: View {
    let request: PaymentRequestModel
    @ObservedObject var viewModel: MerchantViewModel
    @State private var isShowingActions = false
    @State private var isRemoving = false
    @State private var isProcessing = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Main content becomes tappable
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isShowingActions.toggle()
                    }
                }) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.purple.opacity(0.1))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "person")
                                    .foregroundColor(.purple)
                                    .font(.system(size: 14))
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(request.requester?.username ?? "Unknown")
                                .font(.system(size: 15, weight: .medium))
                            if let note = request.note {
                                Text(note)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(request.amount.formatted()) MON")
                                .font(.system(size: 15, weight: .semibold))
                            Text(request.requestTimestamp, style: .relative)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        if request.status == .pending {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                                .rotationEffect(.degrees(isShowingActions ? 90 : 0))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Action buttons slide down when tapped
                if request.status == .pending && isShowingActions {
                    HStack(spacing: 0) {
                        Button(action: { handlePayment(request) }) {
                            Label(isProcessing ? "Processing..." : "Pay", 
                                  systemImage: isProcessing ? "hourglass" : "checkmark")
                                .font(.system(size: 15, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                        }
                        .disabled(isProcessing)
                        
                        Button(action: { handleReject(request) }) {
                            Label("Reject", systemImage: "xmark")
                                .font(.system(size: 15, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                        }
                        .disabled(isProcessing)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            
            // Loading overlay
            if isProcessing {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .opacity(isRemoving ? 0 : 1)
        .animation(.easeOut(duration: 0.2), value: isRemoving)
    }
    
    private func handlePayment(_ request: PaymentRequestModel) {
        Task {
            do {
                withAnimation {
                    isProcessing = true
                    isShowingActions = false
                }
                
                // Get the requester's ethereum wallet address
                guard let requesterWallet = request.requester?.ethereumWallet else {
                    throw APIError.invalidResponse
                }
                
                // Send the transaction
                let transactionHash = try await PrivyService.shared.sendTransaction(
                    amount: NSDecimalNumber(decimal: request.amount).doubleValue,
                    to: requesterWallet
                )
                
                // Update the payment request status
                try await APIService.shared.payPaymentRequest(
                    requestId: request.id.uuidString,
                    transactionHash: transactionHash
                )
                
                // Create payment response message for the card
                // Format: PAYMENT_RESPONSE:APPROVED:txHash:amount:senderAddress:recipientAddress:note
                let responseMessage = "PAYMENT_RESPONSE:APPROVED:\(transactionHash):\(request.amount):\(PrivyService.shared.walletAddress ?? ""):\(requesterWallet):\(request.note ?? "")"
                
                await MainActor.run {
                    // Show payment response card through MerchantView
                    NotificationCenter.default.post(
                        name: .showPaymentResponse,
                        object: nil,
                        userInfo: ["message": responseMessage]
                    )
                    
                    // Update UI
                    withAnimation {
                        isProcessing = false
                        isRemoving = true
                    }
                    
                    // Refresh data
                    viewModel.refreshRequests()
                    Task {
                        await PrivyService.shared.fetchBalance()
                    }
                }
                
            } catch {
                await MainActor.run {
                    isProcessing = false
                    print("Error paying request: \(error)")
                    
                    // Show error in payment response card
                    let errorMessage = "PAYMENT_RESPONSE:DECLINED:error:\(request.amount):\(PrivyService.shared.walletAddress ?? ""):\(request.requester?.ethereumWallet ?? ""):\(error.localizedDescription)"
                    NotificationCenter.default.post(
                        name: .showPaymentResponse,
                        object: nil,
                        userInfo: ["message": errorMessage]
                    )
                }
            }
        }
    }
    
    private func handleReject(_ request: PaymentRequestModel) {
        Task {
            do {
                // First, trigger the fade-out animation
                withAnimation {
                    isShowingActions = false
                }
                
                // Wait for the actions to hide
                try await Task.sleep(for: .milliseconds(200))
                
                // Start the removal animation
                withAnimation {
                    isRemoving = true
                }
                
                // Wait for the fade-out to complete
                try await Task.sleep(for: .milliseconds(200))
                
                // Make the API call
                try await APIService.shared.rejectPaymentRequest(requestId: request.id.uuidString)
                print("Successfully rejected request: \(request.id)")
                
                // Update the UI after everything is done
                await MainActor.run {
                    viewModel.refreshRequests()
                }
                
            } catch {
                // If there's an error, restore the view
                await MainActor.run {
                    isRemoving = false
                    print("Error rejecting request: \(error)")
                }
            }
        }
    }
} 
