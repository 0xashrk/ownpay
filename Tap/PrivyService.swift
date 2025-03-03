import Foundation

class PrivyService: ObservableObject {
    @Published var authState: AuthState = .unauthenticated
    @Published var otpFlowState: OTPFlowState = .initial
    private var otpFlowStateCallback: ((OTPFlowState) -> Void)?
    
    static let shared = PrivyService()
    
    private init() {
        // Initialize Privy with your app ID from Config
        let appId = Config.privyAppId
        // privy.initialize(appId: appId)
    }
    
    func sendCode(to email: String) async -> Bool {
        // Simulate sending code for now
        // Replace with actual Privy implementation
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            updateOTPFlowState(.awaitingCodeInput)
            return true
        } catch {
            updateOTPFlowState(.sendCodeFailure(error))
            return false
        }
    }
    
    func loginWithCode(_ code: String, sentTo email: String) async throws -> AuthState {
        // Simulate verification for now
        // Replace with actual Privy implementation
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            // Simulate successful verification
            if code == "123456" { // For testing purposes
                let authState = AuthState.authenticated(User(id: "test_user", email: email))
                self.authState = authState
                updateOTPFlowState(.done)
                return authState
            } else {
                updateOTPFlowState(.incorrectCode)
                throw AuthError.invalidCode
            }
        } catch {
            updateOTPFlowState(.loginError(error))
            throw error
        }
    }
    
    func setOtpFlowStateChangeCallback(_ callback: @escaping (OTPFlowState) -> Void) {
        otpFlowStateCallback = callback
    }
    
    private func updateOTPFlowState(_ state: OTPFlowState) {
        DispatchQueue.main.async {
            self.otpFlowState = state
            self.otpFlowStateCallback?(state)
        }
    }
}

// MARK: - Models
enum AuthState {
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