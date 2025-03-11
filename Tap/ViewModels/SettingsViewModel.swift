import Foundation
import SwiftUI

enum WalletMode: String, CaseIterable {
    case customer
    case merchant
    case faucet
}

class SettingsViewModel: ObservableObject {
    // Add static shared instance
    static let shared = SettingsViewModel(
        privyService: PrivyService.shared,
        bleService: BLEService()
    )
    
    // UserDefaults key for wallet mode
    private static let walletModeKey = "selectedWalletMode"
    
    // Admin password
    private let adminPassword = "535445"
    
    // Published property that syncs with UserDefaults
    @Published var selectedMode: WalletMode {
        didSet {
            print("Mode changed to: \(selectedMode)")
            // Update isMerchantMode for backward compatibility
            isMerchantMode = selectedMode == .merchant
            // Save to UserDefaults
            UserDefaults.standard.set(selectedMode.rawValue, forKey: Self.walletModeKey)
        }
    }
    
    @Published var isMerchantMode: Bool = false {
        didSet {
            // Only update selectedMode if this property is changed directly
            if isMerchantMode && selectedMode != .merchant {
                selectedMode = .merchant
            } else if !isMerchantMode && selectedMode == .merchant {
                selectedMode = .customer
            }
        }
    }
    
    @Published var isLoggingOut = false
    @Published var logoutError: String?
    
    // Password protection properties
    @Published var showingPasswordPrompt = false
    @Published var enteredPassword = ""
    @Published var passwordError = false
    @Published var isPasswordVerified = false
    
    let privyService: PrivyService
    let bleService: BLEService
    
    init(privyService: PrivyService, bleService: BLEService) {
        self.privyService = privyService
        self.bleService = bleService
        
        // Load saved mode from UserDefaults, default to customer if not found
        if let savedModeString = UserDefaults.standard.string(forKey: Self.walletModeKey),
           let savedMode = WalletMode(rawValue: savedModeString) {
            self.selectedMode = savedMode
        } else {
            self.selectedMode = .customer
        }
        
        // Ensure isMerchantMode is consistent with selectedMode on initialization
        self.isMerchantMode = self.selectedMode == .merchant
    }
    
    func logout() async {
        isLoggingOut = true
        do {
            try await privyService.logout()
            isLoggingOut = false
        } catch {
            logoutError = error.localizedDescription
            isLoggingOut = false
        }
    }
    
    func toggleMerchantMode() {
        isMerchantMode.toggle()
    }
    
    // Password verification
    func verifyPassword(_ password: String) -> Bool {
        let isCorrect = password == adminPassword
        passwordError = !isCorrect
        isPasswordVerified = isCorrect
        return isCorrect
    }
    
    func resetPasswordState() {
        enteredPassword = ""
        isPasswordVerified = false
        passwordError = false
    }
} 
