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
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "person")
                            .foregroundColor(.purple)
                            .font(.system(size: 14))
                    )
                
                // Request details
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
                
                // Amount
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(request.amount.formatted()) MON")
                        .font(.system(size: 15, weight: .semibold))
                    Text(request.requestTimestamp, style: .relative)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            
            // Action buttons
            if request.status == .pending {
                HStack(spacing: 1) {
                    Button(action: { handlePayment(request) }) {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Pay")
                        }
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                    }
                    
                    Button(action: { handleReject(request) }) {
                        HStack {
                            Image(systemName: "xmark")
                            Text("Reject")
                        }
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 2)
//        .padding(.horizontal, 8)
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
