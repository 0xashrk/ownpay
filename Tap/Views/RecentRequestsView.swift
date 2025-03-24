import SwiftUI

struct RecentRequestsView: View {
    @ObservedObject var viewModel: MerchantViewModel
    @Environment(\.colorScheme) var colorScheme
    
    private var surfaceColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerSection
            
            if viewModel.isRecentRequestsExpanded {
                content
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var headerSection: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.isRecentRequestsExpanded.toggle()
            }
        }) {
            HStack {
                Text("Recent Requests")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.leading, 4)
                }
                
                Spacer()
                
                Image(systemName: viewModel.isRecentRequestsExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            loadingView
        } else if let error = viewModel.error {
            errorView(error)
        } else if viewModel.recentRequests.isEmpty {
            emptyView
        } else {
            requestsList
        }
    }
    
    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity)
            .padding()
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(.red)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
                .padding()
            
            Text("No Recent Requests")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Payment requests will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
    
    private var requestsList: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.recentRequests, id: \.id) { request in
                RequestRowView(request: request)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

struct RequestRowView: View {
    let request: PaymentRequestModel
    @Environment(\.colorScheme) var colorScheme
    
    private var surfaceColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // User info and amount
            HStack(alignment: .top, spacing: 12) {
                // Avatar
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.purple)
                    )
                
                // Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.requester?.username ?? "Unknown")
                        .font(.headline)
                    
                    if let note = request.note {
                        Text(note)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(request.requestTimestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Amount
                Text("\(request.amount.formatted()) MON")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                ActionButton(title: "Pay", color: .blue) {
                    // TODO: Implement pay action
                }
                
                ActionButton(title: "Reject", color: .red) {
                    // TODO: Implement reject action
                }
            }
        }
        .padding()
        .background(surfaceColor)
        .cornerRadius(16)
    }
}

struct ActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }
} 