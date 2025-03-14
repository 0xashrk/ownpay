import Foundation
import SwiftUI
import Combine

class UserProfileService: ObservableObject {
    static let shared = UserProfileService()
    
    @Published var username: String?
    @Published var isLoadingProfile = false
    @Published var profileError: String?
    
    // Use AppStorage only as a fallback, not as the primary source
    @AppStorage("storedUsername") private var storedUsername: String?
    @AppStorage("lastProfileFetchTime") private var lastFetchTimeStamp: Double = 0
    
    // Add cancellables for when app state changes
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Initialize with saved username temporarily
        self.username = storedUsername
        
        // Immediately trigger a refresh on startup
        Task {
            await fetchUserProfile(silently: true)
        }
        
        // Also refresh when the app becomes active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.fetchUserProfile(silently: true)
                }
            }
            .store(in: &cancellables)
    }
    
    // Force refresh from backend with option to hide loading indicators
    @MainActor
    func fetchUserProfile(silently: Bool = false) async {
        // Don't fetch if we're already loading
        guard !isLoadingProfile else { return }
        
        // Reset error state
        profileError = nil
        
        // Only show loading indicators if not silent
        if !silently {
            isLoadingProfile = true
        }
        
        // Get the user ID from PrivyService
        guard let userId = PrivyService.shared.getUserId() else {
            isLoadingProfile = false
            if !silently {
                profileError = "User ID not available"
            }
            return
        }
        
        do {
            // Always fetch the latest profile from the backend
            let profileResponse = try await APIService.shared.getUserProfile(userId: userId)
            
            // Update the username with the fresh data
            self.username = profileResponse.username
            
            // Cache it for offline fallback
            self.storedUsername = profileResponse.username
            
            // Update the last fetch timestamp
            self.lastFetchTimeStamp = Date().timeIntervalSince1970
            
            print("Profile updated from backend: \(profileResponse.username)")
        } catch {
            print("Error fetching user profile: \(error.localizedDescription)")
            if !silently {
                self.profileError = error.localizedDescription
            }
        }
        
        if !silently {
            isLoadingProfile = false
        }
    }
    
    // Call this method when the user logs out
    func clearProfile() {
        username = nil
        storedUsername = nil
        profileError = nil
        lastFetchTimeStamp = 0
    }
    
    // Add this method to UserProfileService class
    @MainActor
    func updateUsername(_ newUsername: String) {
        // Update the current username
        self.username = newUsername
        
        // Cache it for offline fallback
        self.storedUsername = newUsername
        
        // Update the last fetch timestamp to now
        self.lastFetchTimeStamp = Date().timeIntervalSince1970
        
        print("Username updated locally: \(newUsername)")
    }
} 