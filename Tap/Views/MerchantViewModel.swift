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
                    // Filter to only show pending requests
                    self.recentRequests = requests.filter { $0.status == .pending }
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
    
    // Add a function to refresh requests after actions
    func refreshRequests() {
        Task {
            do {
                let requests = try await APIService.shared.getReceivedPaymentRequests()
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.recentRequests = requests.filter { $0.status == .pending }
                    }
                }
            } catch {
                print("Error refreshing requests: \(error)")
            }
        }
    }
    
    func dismissAll() {
        navigationPath.removeLast(navigationPath.count)  // Clear navigation stack
        showingFriendPicker = false  // Dismiss sheet
    }
}
