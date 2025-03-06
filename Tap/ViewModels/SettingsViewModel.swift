import Foundation
import SwiftUI

class SettingsViewModel: ObservableObject {
    @Published var isLoggingOut = false
    @Published var logoutError: String?
    
    private let privyService: PrivyService
    private let bleService: BLEService
    
    init(privyService: PrivyService, bleService: BLEService) {
        self.privyService = privyService
        self.bleService = bleService
    }
    
    func logout() async {
        isLoggingOut = true
        logoutError = nil
        
        do {
            // Clean up communication services
            bleService.disconnect()
            bleService.stopScanning()
            bleService.stopAdvertising()
            
            // Logout from Privy
            try await privyService.logout()
        } catch {
            logoutError = "Failed to logout: \(error.localizedDescription)"
            print("Logout error: \(error)")
        }
        
        isLoggingOut = false
    }
} 