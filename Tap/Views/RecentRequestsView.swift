import SwiftUI

struct RecentRequestsView: View {
    @ObservedObject var viewModel: MerchantViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerSection
            
            if viewModel.isRecentRequestsExpanded {
                requestsList
            }
        }
    }
    
    private var headerSection: some View {
        Button(action: {
            withAnimation(.easeInOut) {
                viewModel.isRecentRequestsExpanded.toggle()
            }
        }) {
            HStack {
                Text("Recent Requests")
                    .font(.headline)
                Spacer()
                Image(systemName: viewModel.isRecentRequestsExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
            }
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
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.recentRequests, id: \.id) { request in
                            RequestRow(request: request)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

struct RequestRow: View {
    let request: PaymentRequestModel
    
    var body: some View {
        VStack(spacing: 4) {
            // Username and amount
            HStack {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person")
                                .foregroundColor(.purple)
                                .font(.system(size: 14))
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(request.requester?.username ?? "Unknown")
                            .font(.system(size: 16))
                        
                        if let note = request.note {
                            Text(note)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(request.requestTimestamp, style: .relative)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text("\(request.amount.formatted()) MON")
                    .font(.system(size: 16, weight: .semibold))
            }
            
            if request.status == .pending {
                HStack(spacing: 8) {
                    Button(action: { handlePayment(request) }) {
                        Text("Pay")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: { handleReject(request) }) {
                        Text("Reject")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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