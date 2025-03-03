import Foundation
import PrivySDK

class PrivyService: ObservableObject {
    @Published var authState: PrivySDK.AuthState = .notReady
    @Published var otpFlowState: PrivySDK.OtpFlowState = .initial
    @Published var isReady = false
    @Published var walletAddress: String?
    @Published var balance: String?
    @Published var embeddedWalletState: EmbeddedWalletState = .notConnected
    @Published private var isWalletOperationInProgress = false
    
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
                
                // Get wallet address from auth session if available
                if case .authenticated(let session) = state {
                    if let ethereumWallet = session.user.linkedAccounts.first(where: { account in
                        if case .embeddedWallet(let wallet) = account {
                            return wallet.chainType == .ethereum
                        }
                        return false
                    }) {
                        if case .embeddedWallet(let wallet) = ethereumWallet {
                            self.walletAddress = wallet.address
                            self.embeddedWalletState = .connected(wallets: [Wallet(address: wallet.address)])
                            print("Found wallet from auth session: \(wallet.address)")
                        }
                    }
                    
                    // Still try to connect wallet in background
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
        // Prevent multiple concurrent wallet operations
        guard !isWalletOperationInProgress else {
            print("Wallet operation already in progress, skipping...")
            return
        }
        
        isWalletOperationInProgress = true
        print("Connecting wallet...")
        
        do {
            // First check if we already have a wallet in the auth session
            if case .authenticated(let session) = authState {
                if let ethereumWallet = session.user.linkedAccounts.first(where: { account in
                    if case .embeddedWallet(let wallet) = account {
                        return wallet.chainType == .ethereum
                    }
                    return false
                }) {
                    if case .embeddedWallet(let wallet) = ethereumWallet {
                        self.walletAddress = wallet.address
                        self.embeddedWalletState = .connected(wallets: [Wallet(address: wallet.address)])
                        print("Using wallet from auth session: \(wallet.address)")
                        
                        // Get the provider for this specific wallet
                        ethereumProvider = try privy.embeddedWallet.getEthereumProvider(for: wallet.address)
                        print("Got ethereum provider for wallet")
                        
                        // Try to fetch balance
                        await self.fetchBalance()
                        isWalletOperationInProgress = false
                        return
                    }
                }
            }
            
            // If no wallet in auth session, check embedded wallet state
            if case .connected(let wallets) = privy.embeddedWallet.embeddedWalletState {
                if let wallet = wallets.first, wallet.chainType == .ethereum {
                    print("Found existing wallet: \(wallet.address)")
                    self.walletAddress = wallet.address
                    self.embeddedWalletState = .connected(wallets: [Wallet(address: wallet.address)])
                    
                    // Get the provider for this specific wallet
                    ethereumProvider = try privy.embeddedWallet.getEthereumProvider(for: wallet.address)
                    print("Got ethereum provider for wallet")
                    
                    // Try to fetch balance
                    await self.fetchBalance()
                    isWalletOperationInProgress = false
                    return
                }
            }
            
            // If no wallet found, create one
            print("No existing wallet found, creating embedded wallet...")
            self.embeddedWalletState = .connecting
            try await privy.embeddedWallet.createWallet(allowAdditional: false)
            
            // Wait a bit for the wallet creation to complete
            try await Task.sleep(nanoseconds: 2 * 1_000_000_000) // 2 seconds
            
            // Check if wallet was created successfully
            if case .connected(let wallets) = privy.embeddedWallet.embeddedWalletState,
               let wallet = wallets.first, wallet.chainType == .ethereum {
                print("Wallet created successfully: \(wallet.address)")
                self.walletAddress = wallet.address
                self.embeddedWalletState = .connected(wallets: [Wallet(address: wallet.address)])
                
                // Get the provider for this specific wallet
                ethereumProvider = try privy.embeddedWallet.getEthereumProvider(for: wallet.address)
                print("Got ethereum provider for wallet")
                
                // Try to fetch balance
                await self.fetchBalance()
            } else {
                print("Wallet creation completed but no wallet found")
                throw WalletError.creationFailed
            }
        } catch {
            print("Error with wallet operation: \(error)")
            self.embeddedWalletState = .notConnected
            self.ethereumProvider = nil
        }
        
        isWalletOperationInProgress = false
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
    
    @MainActor
    func fetchBalance() async {
        guard case .connected(let wallets) = privy.embeddedWallet.embeddedWalletState else {
            print("Cannot fetch balance: Wallet not connected")
            return
        }
        
        // Find an Ethereum wallet
        guard let wallet = wallets.first, wallet.chainType == .ethereum else {
            print("Cannot fetch balance: No Ethereum wallets available")
            return
        }
        
        do {
            // Get the provider specifically for this wallet
            let provider = try privy.embeddedWallet.getEthereumProvider(for: wallet.address)
            print("Got ethereum provider for wallet: \(wallet.address)")
            
            // Create RPC request for eth_getBalance
            let request = RpcRequest(
                method: "eth_getBalance",
                params: [wallet.address, "latest"]
            )
            
            // Make the RPC call
            let response = try await provider.request(request)
            print("Got balance response: \(response)")
            
            // Parse the hex balance
            if let hexBalance = response as? String {
                let balanceHex = hexBalance.replacingOccurrences(of: "0x", with: "")
                if let balanceDecimal = Int(balanceHex, radix: 16) {
                    // Convert from Wei to ETH
                    let ethBalance = Double(balanceDecimal) / 1e18
                    balance = String(format: "%.4f ETH", ethBalance)
                    print("Updated balance: \(balance ?? "nil")")
                }
            }
        } catch {
            print("Error fetching balance: \(error)")
            balance = "Error"
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
