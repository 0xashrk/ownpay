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
                Text("No recent requests")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.recentRequests, id: \.id) { request in
                            RequestRow(request: request)
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
    @State private var isShowingActions = false
    
    var body: some View {
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
                    Button(action: { 
                        isShowingActions = false
                        handlePayment(request) 
                    }) {
                        Label("Pay", systemImage: "checkmark")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: { 
                        isShowingActions = false
                        handleReject(request) 
                    }) {
                        Label("Reject", systemImage: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
    
    private func handlePayment(_ request: PaymentRequestModel) {
        Task {
            do {
                // TODO: Implement payment logic
                print("Processing payment for request: \(request.id)")
            } catch {
                print("Error processing payment: \(error)")
            }
        }
    }
    
    private func handleReject(_ request: PaymentRequestModel) {
        Task {
            do {
                // TODO: Implement reject logic
                print("Rejecting request: \(request.id)")
            } catch {
                print("Error rejecting request: \(error)")
            }
        }
    }
} 
