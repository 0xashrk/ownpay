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
    
    // Wallet address copy state
    @Published var addressCopied = false
    
    // API connection test properties
    @Published var apiTestResult: String? = nil
    @Published var isTestingApi = false
    @Published var apiTestError: String? = nil
    
    @Published var navigationPath = NavigationPath()
    
    let privyService: PrivyService
    let bleService: BLEService
    let userProfileService = UserProfileService.shared
    
    init(privyService: PrivyService, bleService: BLEService) {
        self.privyService = privyService
        self.bleService = bleService
        
        // Load saved mode from UserDefaults, default to customer if not found
        if let savedModeString = UserDefaults.standard.string(forKey: Self.walletModeKey),
           let savedMode = WalletMode(rawValue: savedModeString) {
            self.selectedMode = savedMode
        } else {
            self.selectedMode = .merchant
        }
        
        // Ensure isMerchantMode is consistent with selectedMode on initialization
        self.isMerchantMode = self.selectedMode == .merchant
    }
    
    // MARK: - User Profile Functions
    
    func refreshUserProfile(silently: Bool = true, forceRefresh: Bool = false) async {
        await userProfileService.fetchUserProfile(silently: silently, bypassRateLimit: forceRefresh, forceRefresh: forceRefresh)
    }
    
    // MARK: - Wallet Address Functions
    
    func copyWalletAddress() {
        guard let address = privyService.walletAddress else { return }
        
        #if os(iOS)
        UIPasteboard.general.string = address
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(address, forType: .string)
        #endif
        
        // Show copied indicator
        addressCopied = true
        
        // Reset copied status after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.addressCopied = false
        }
    }
    
    // MARK: - Mode Helper Functions
    
    func iconForMode(_ mode: WalletMode) -> String {
        switch mode {
        case .customer:
            return "person.fill"
        case .merchant:
            return "storefront.fill"
        case .faucet:
            return "drop.fill"
        }
    }
    
    func titleForMode(_ mode: WalletMode) -> String {
        switch mode {
        case .customer:
            return "Customer Mode"
        case .merchant:
            return "Merchant Mode"
        case .faucet:
            return "Faucet Mode"
        }
    }
    
    // MARK: - API Connection Test
    
    func testApiConnection() {
        // Reset state on main thread
        Task { @MainActor in
            apiTestResult = nil
            apiTestError = nil
            isTestingApi = true
            
            do {
                let result = try await APIService.shared.testApiConnection()
                self.apiTestResult = "Success: \(result.message)"
                self.isTestingApi = false
            } catch {
                self.apiTestError = "Error: \(error.localizedDescription)"
                self.isTestingApi = false
            }
        }
    }
    
    // MARK: - Authentication Functions
    
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
    
    func navigateToWalletModes() {
        navigationPath.append("walletModes")
    }
    
    func dismissWalletModes() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
} 
