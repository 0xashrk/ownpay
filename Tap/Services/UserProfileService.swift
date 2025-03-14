import Foundation
import SwiftUI

class UserProfileService: ObservableObject {
    static let shared = UserProfileService()
    
    @Published var username: String?
    @Published var isLoadingProfile = false
    @Published var profileError: String?
    
    // Use AppStorage to persist the username across app launches
    @AppStorage("storedUsername") private var storedUsername: String?
    
    private init() {
        // Initialize with saved username if available
        self.username = storedUsername
    }
    
    @MainActor
    func fetchUserProfile() async {
        // Don't fetch if we're already loading
        guard !isLoadingProfile else { return }
        
        // Reset error state
        profileError = nil
        isLoadingProfile = true
        
        // Get the user ID from PrivyService
        guard let userId = PrivyService.shared.getUserId() else {
            isLoadingProfile = false
            profileError = "User ID not available"
            return
        }
        
        do {
            // Fetch the profile using the API
            let profileResponse = try await APIService.shared.getUserProfile(userId: userId)
            
            // Update the username
            self.username = profileResponse.username
            
            // Store the username for persistence
            self.storedUsername = profileResponse.username
        } catch {
            print("Error fetching user profile: \(error.localizedDescription)")
            self.profileError = error.localizedDescription
        }
        
        isLoadingProfile = false
    }
    
    // Call this method when the user logs out
    func clearProfile() {
        username = nil
        storedUsername = nil
        profileError = nil
    }
} 