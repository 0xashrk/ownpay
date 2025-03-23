import Foundation

class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    func loadFriends() {
        isLoading = true
        error = nil
        
        print("🔄 Starting to load friends...")
        
        Task {
            do {
                print("📡 Making API request to fetch user profiles...")
                let profiles = try await APIService.shared.getUserProfiles()
                print("📥 Received \(profiles.count) profiles from API")
                
                await MainActor.run {
                    self.friends = profiles.map { profile in
                        Friend(
                            id: profile.id,
                            name: profile.username,
                            username: "@\(profile.username)",
                            avatarName: "person.crop.circle.fill"
                        )
                    }
                    self.isLoading = false
                }
            } catch {
                print("❌ Error in loadFriends: \(error)")
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
}
