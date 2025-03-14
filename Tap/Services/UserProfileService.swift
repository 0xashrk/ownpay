import Foundation
import SwiftUI
import Combine

class UserProfileService: ObservableObject {
    static let shared = UserProfileService()
    
    // Make this public so views can access it directly
    @AppStorage("storedUsername") public var storedUsername: String?
    
    // Keep the published property for backward compatibility
    @Published var username: String?
    
    @Published var isLoadingProfile = false
    @Published var profileError: String?
    
    @AppStorage("lastProfileFetchTime") private var lastFetchTimeStamp: Double = 0
    
    // Add cancellables for when app state changes
    private var cancellables = Set<AnyCancellable>()
    
    // Add these properties to UserProfileService
    private let minRefreshInterval: TimeInterval = 30 // 30 seconds between manual refreshes
    private var lastManualRefreshTime: Date = Date.distantPast
    
    private init() {
        // Initialize published property from AppStorage
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
    func fetchUserProfile(silently: Bool = false, bypassRateLimit: Bool = false, forceRefresh: Bool = false) async {
        // Don't fetch if we're already loading
        guard !isLoadingProfile else { return }
        
        // Skip rate limiting if bypassed or forced
        if !silently && !bypassRateLimit && !forceRefresh {
            let timeElapsed = Date().timeIntervalSince(lastManualRefreshTime)
            if timeElapsed < minRefreshInterval {
                // Too soon since last refresh, show temporary message
                profileError = "Please wait \(Int(minRefreshInterval - timeElapsed)) seconds before refreshing again"
                
                // Auto-clear the error after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.profileError = nil
                }
                return
            }
        }
        
        // Reset error state
        profileError = nil
        
        // Only show loading indicators if not silent
        if !silently {
            isLoadingProfile = true
            lastManualRefreshTime = Date() // Update last refresh time
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
            
            // Debug logging to confirm we got a new response
            print("Backend username fetch result: \(profileResponse.username), previous: \(self.username ?? "none")")
            
            // Update BOTH properties
            self.username = profileResponse.username
            self.storedUsername = profileResponse.username // This will trigger SwiftUI updates
            
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
    
    // Update both properties when updating username
    @MainActor
    func updateUsername(_ newUsername: String) {
        // Update both the published property and AppStorage
        self.username = newUsername
        self.storedUsername = newUsername
        
        // Update the last fetch timestamp to now
        self.lastFetchTimeStamp = Date().timeIntervalSince1970
        
        print("Username updated locally: \(newUsername)")
    }
    
    // Clear both properties on logout
    func clearProfile() {
        username = nil
        storedUsername = nil
        profileError = nil
        lastFetchTimeStamp = 0
    }
} 