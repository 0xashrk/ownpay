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
    
    @Published var selectedMode: WalletMode = .customer {
        didSet {
            print("Mode changed to: \(selectedMode)")
            // Update isMerchantMode for backward compatibility
            isMerchantMode = selectedMode == .merchant
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
    
    let privyService: PrivyService
    let bleService: BLEService
    
    init(privyService: PrivyService, bleService: BLEService) {
        self.privyService = privyService
        self.bleService = bleService
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
} 
