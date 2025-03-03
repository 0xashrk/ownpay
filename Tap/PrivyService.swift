import Foundation
import PrivySDK

class PrivyService: ObservableObject {
    @Published var authState: PrivySDK.AuthState = .notReady
    @Published var otpFlowState: PrivySDK.OtpFlowState = .initial
    @Published var isReady = false
    
    static let shared = PrivyService()
    private var privy: Privy!
    
    private init() {
        print("Initializing PrivyService with appId: \(Config.privyAppId)")
        print("Client ID: \(Config.privyClientId)")
        
        let config = PrivyConfig(appId: Config.privyAppId, appClientId: Config.privyClientId)
        privy = PrivySdk.initialize(config: config)
        
        // Set up auth state change callback
        privy.setAuthStateChangeCallback { [weak self] state in
            guard let self = self else { return }
            print("Auth state changed to: \(state)")
            DispatchQueue.main.async {
                self.authState = state
                if !self.isReady && state != .notReady {
                    self.isReady = true
                    print("PrivyService is now ready")
                }
            }
        }
        
        // Set up OTP flow state callback
        privy.email.setOtpFlowStateChangeCallback { [weak self] state in
            guard let self = self else { return }
            print("OTP flow state changed to: \(state)")
            DispatchQueue.main.async {
                self.otpFlowState = state
            }
        }
    }
    
    func sendCode(to email: String) async -> Bool {
        print("Attempting to send code to: \(email)")
        do {
            let result = await privy.email.sendCode(to: email)
            print("Send code result: \(result)")
            return result
        } catch {
            print("Error sending code: \(error)")
            return false
        }
    }
    
    func loginWithCode(_ code: String, sentTo email: String) async throws -> PrivySDK.AuthState {
        print("Attempting to verify code for: \(email)")
        do {
            let result = try await privy.email.loginWithCode(code, sentTo: email)
            print("Login result: \(result)")
            return result
        } catch {
            print("Error verifying code: \(error)")
            throw error
        }
    }
    
    @MainActor
    func logout() async {
        print("Logging out...")
        do {
            try await privy.logout()
            self.authState = .unauthenticated
            self.otpFlowState = .initial
            print("Logout successful")
        } catch {
            print("Error during logout: \(error)")
            // Still set to unauthenticated even if logout fails
            self.authState = .unauthenticated
        }
    }
}

// MARK: - Models
enum AuthState {
    case notReady
    case unauthenticated
    case authenticated(User)
}

struct User {
    let id: String
    let email: String
}

enum AuthError: Error {
    case invalidCode
    case networkError
    case unknown
}

enum OTPFlowState {
    case initial
    case sourceNotSpecified
    case sendCodeFailure(Error)
    case sendingCode
    case awaitingCodeInput
    case submittingCode
    case incorrectCode
    case loginError(Error)
    case done
} 