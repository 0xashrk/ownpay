import Foundation
import SwiftUI

class MerchantViewModel: ObservableObject {
    @Published var selectedFriend: Friend?
    @Published var showingFriendPicker = false
    @Published var showingRequestForm = false
    @Published var recentRequests: [PaymentRequestModel] = []
    @Published var isRecentRequestsExpanded: Bool = true
    @Published var navigationPath = NavigationPath()
    @Published var isLoading = false
    @Published var error: Error?
    
    func loadRecentRequests() {
        Task {
            await MainActor.run {
                self.isLoading = true
                self.error = nil
            }
            
            do {
                let requests = try await APIService.shared.getReceivedPaymentRequests()
                await MainActor.run {
                    self.recentRequests = requests
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    func dismissAll() {
        navigationPath.removeLast(navigationPath.count)  // Clear navigation stack
        showingFriendPicker = false  // Dismiss sheet
    }
}
