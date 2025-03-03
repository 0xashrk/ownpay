import Foundation
import PrivySDK

class PrivyService: ObservableObject {
    @Published var authState: PrivySDK.AuthState = .notReady
    @Published var otpFlowState: PrivySDK.OtpFlowState = .initial
    @Published var isReady = false
    @Published var walletAddress: String?
    @Published var embeddedWalletState: EmbeddedWalletState = .notConnected
    
    static let shared = PrivyService()
    private var privy: Privy!
    private var ethereumProvider: EthereumEmbeddedWalletProvider?
    
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
                
                // When authenticated, create/connect wallet
                if case .authenticated = state {
                    Task {
                        await self.connectWallet()
                    }
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
        let result = await privy.email.sendCode(to: email)
        print("Send code result: \(result)")
        return result
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
    func connectWallet() async {
        print("Connecting wallet...")
        do {
            // Get the embedded wallet provider
            if ethereumProvider == nil {
                ethereumProvider = try privy.embeddedWallet.getEthereumProvider(for: "ethereum")
            }
            
            guard let provider = ethereumProvider else {
                throw WalletError.providerNotInitialized
            }
            
            // Create a new wallet if needed
            let request = RpcRequest(method: "eth_accounts", params: [])
            let response = try await provider.request(request)
            
            if let accounts = response as? [String], let address = accounts.first {
                // Wallet exists, update state
                self.walletAddress = address
                self.embeddedWalletState = .connected(wallets: [Wallet(address: address)])
                print("Found existing wallet: \(address)")
            } else {
                // Create a new wallet
                print("No existing wallet found, creating new one...")
                let createRequest = RpcRequest(method: "eth_requestAccounts", params: [])
                let createResponse = try await provider.request(createRequest)
                
                if let newAccounts = createResponse as? [String], let newAddress = newAccounts.first {
                    self.walletAddress = newAddress
                    self.embeddedWalletState = .connected(wallets: [Wallet(address: newAddress)])
                    print("Created new wallet: \(newAddress)")
                } else {
                    throw WalletError.creationFailed
                }
            }
        } catch {
            print("Error with wallet operation: \(error)")
            self.embeddedWalletState = .notConnected
            self.ethereumProvider = nil
        }
    }
    
    @MainActor
    func logout() async throws {
        print("Logging out...")
        self.ethereumProvider = nil
        try await privy.logout()
        
        self.authState = .unauthenticated
        self.otpFlowState = .initial
        self.walletAddress = nil
        self.embeddedWalletState = .notConnected
        print("Logout successful")
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

enum WalletError: Error {
    case creationFailed
    case providerNotInitialized
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

enum EmbeddedWalletState {
    case notConnected
    case connecting
    case connected(wallets: [Wallet])
}

struct Wallet {
    let address: String
} 