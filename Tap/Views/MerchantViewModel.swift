import Foundation

class MerchantViewModel: ObservableObject {
    @Published var selectedFriend: Friend?
    @Published var showingFriendPicker = false
    @Published var showingRequestForm = false
    @Published var recentRequests: [PaymentRequest] = []
    @Published var isRecentRequestsExpanded: Bool = true
    
    func loadFriends() {
        // In a real app, this would load friends from your backend
    }
    
    func loadRecentRequests() {
        // This would fetch recent payment requests from your backend
        // For now, let's add some sample data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.recentRequests = [
                PaymentRequest(
                    id: "1",
                    title: "Alex Chen",
                    description: "Lunch payment",
                    amount: "5.00 MON",
                    timeAgo: "2h ago",
                    type: .user
                ),
                PaymentRequest(
                    id: "2",
                    title: "Nearby Request",
                    description: "Coffee shop",
                    amount: "3.50 MON",
                    timeAgo: "Yesterday",
                    type: .nearby
                )
            ]
        }
    }
}
