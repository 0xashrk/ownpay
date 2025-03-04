import Foundation
import PrivySDK

class PrivyService: ObservableObject {
    @Published var authState: PrivySDK.AuthState = .notReady
    @Published var otpFlowState: PrivySDK.OtpFlowState = .initial
    @Published var isReady = false
    @Published var walletAddress: String?
    @Published var balance: String?
    @Published var monBalance: String?
    @Published var embeddedWalletState: EmbeddedWalletState = .notConnected
    @Published private var isWalletOperationInProgress = false
    
    // Add default values as published properties
    @Published var defaultRecipientAddress: String = "0x7C9976116d7d65cfE84580FEdBB2D96A0C6434C6"
    @Published var defaultAmount: Double = 2.0
    
    static let shared = PrivyService()
    private var privy: Privy!
    private var ethereumProvider: EthereumEmbeddedWalletProvider?
    
    // Update RPC URL to Monad testnet
    private let monadRPCURL = "https://lb.drpc.org/ogrpc?network=monad-testnet&dkey=AnChAsqfqkWPkLaja7Bky5eCjS9e748R776n0mSYF3e0"
    
    // Add MON token contract address for Monad testnet
    private let monTokenAddress = "0xB5a30b0FDc5EA94A52fDc42e3E9760Cb8449Fb37" // Replace with actual MON token address
    
    // Add chain parameters as a property to ensure consistency
    private let monadChainParams: [String: Any] = [
        "chainId": "0x279f",
        "chainName": "Monad Testnet",
        "nativeCurrency": [
            "name": "MON",
            "symbol": "MON",
            "decimals": 18
        ],
        "rpcUrls": ["https://lb.drpc.org/ogrpc?network=monad-testnet&dkey=AnChAsqfqkWPkLaja7Bky5eCjS9e748R776n0mSYF3e0"],
        "blockExplorerUrls": ["https://testnet-explorer.monad.xyz"],
        "iconUrls": ["https://testnet-explorer.monad.xyz/favicon.ico"]
    ]
    
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
                        print("Found wallet from auth session: \(wallet.address)")
                        
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
            _ = try await privy.embeddedWallet.createWallet(chainType: .ethereum, allowAdditional: false)
            
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
        guard let address = walletAddress else { return }
        
        do {
            print("Fetching balance for address: \(address)")
            // Fetch native token balance
            let url = URL(string: monadRPCURL)!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Get native token balance
            let nativeBalanceJson: [String: Any] = [
                "jsonrpc": "2.0",
                "method": "eth_getBalance",
                "params": [address, "latest"],
                "id": 1
            ]
            
            print("Sending request with JSON: \(nativeBalanceJson)")
            request.httpBody = try JSONSerialization.data(withJSONObject: nativeBalanceJson)
            let (data, _) = try await URLSession.shared.data(for: request)
            let responseString = String(data: data, encoding: .utf8) ?? "Could not decode response"
            print("Received response: \(responseString)")
            
            // First try to decode as error response
            if let errorResponse = try? JSONDecoder().decode(JSONRPCErrorResponse.self, from: data) {
                print("RPC Error: \(errorResponse.error.message)")
                throw WalletError.rpcError(errorResponse.error.message)
            }
            
            // If not an error, decode as success response
            let response = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
            
            // Convert hex balance to MON (since we're on Monad testnet)
            let balanceHex = response.result
            print("Raw balance hex: \(balanceHex)")
            
            // Remove "0x" prefix and convert to decimal using UInt64
            let hexString = balanceHex.dropFirst(2)
            let balance = Double(UInt64(hexString, radix: 16) ?? 0) / 1e18
            print("Converted balance: \(balance) MON")
            
            await MainActor.run {
                self.balance = String(format: "%.4f MON", balance)
            }
            
            // Since we're on Monad testnet, we don't need to fetch MON token balance separately
            // as MON is the native token
            await MainActor.run {
                self.monBalance = nil // Clear MON balance since it's the same as native balance
            }
        } catch {
            print("Error fetching balance: \(error)")
            print("Error details: \(String(describing: error))")
            await MainActor.run {
                self.balance = "Error"
                self.monBalance = nil
            }
        }
    }
    
    @MainActor
    func sendTransaction() async throws {
        guard case .connected(let wallets) = privy.embeddedWallet.embeddedWalletState else {
            print("Wallet not connected")
            return
        }

        guard let wallet = wallets.first, wallet.chainType == .ethereum else {
            print("No Ethereum wallets available")
            return
        }

        // First get the nonce
        let provider = try privy.embeddedWallet.getEthereumProvider(for: wallet.address)
        let nonceResponse = try await provider.request(
            RpcRequest(
                method: "eth_getTransactionCount",
                params: [wallet.address, "latest"]
            )
        )
        
        // Extract just the nonce value from the response
        let nonce: String
        if let response = nonceResponse as? [String: Any],
           let result = response["result"] as? String {
            nonce = result
        } else {
            nonce = "0x0"
        }
        print("Got nonce: \(nonce)")

        // Create the transfer data for the MON token contract
        let transferData = "0xa9059cbb" + // transfer function signature
            "000000000000000000000000" + defaultRecipientAddress.dropFirst(2) + // recipient address
            "0000000000000000000000000000000000000000000000005af3107a4000" // amount in hex (100000000000000)

        // Create transaction object with EIP-1559 parameters
        let tx = [
            "value": "0x0", // No ETH value needed for token transfer
            "to": monTokenAddress, // MON token contract address
            "chainId": "0x279f", // Monad testnet chainId
            "from": wallet.address, // logged in user's embedded wallet address
            "gas": toHexString(100000), // Higher gas limit for token transfer
            "maxFeePerGas": toHexString(1000000000000), // 1 Gwei
            "maxPriorityFeePerGas": toHexString(500000000000), // 0.5 Gwei
            "nonce": nonce,
            "data": transferData // The encoded transfer function call
        ]

        // Convert transaction to JSON string
        let txData = try JSONSerialization.data(withJSONObject: tx)
        guard let txString = String(data: txData, encoding: .utf8) else {
            print("Failed to convert transaction to string")
            return
        }
        print("Transaction data: \(txString)")

        // Sign the transaction using the provider
        let signedTx = try await provider.request(
            RpcRequest(
                method: "eth_signTransaction",
                params: [txString]
            )
        )

        guard let signedTxString = signedTx as? String else {
            print("Failed to sign transaction")
            return
        }

        print("Got signed transaction: \(signedTxString)")

        // Create a direct RPC request to the Monad testnet
        let url = URL(string: monadRPCURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let rpcRequest: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_sendRawTransaction",
            "params": [signedTxString],
            "id": 1
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: rpcRequest)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let responseString = String(data: data, encoding: .utf8) ?? "Could not decode response"
        print("Received response: \(responseString)")
        
        // First try to decode as error response
        if let errorResponse = try? JSONDecoder().decode(JSONRPCErrorResponse.self, from: data) {
            print("RPC Error: \(errorResponse.error.message)")
            throw WalletError.rpcError(errorResponse.error.message)
        }
        
        // If not an error, decode as success response
        let response = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
        print("Transaction sent successfully: \(response.result)")
    }
    
    // Add this helper function
    private func toHexString(_ number: UInt64) -> String {
        return "0x" + String(format: "%llx", number)
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
    case rpcError(String)
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

// Add JSON-RPC response structure
struct JSONRPCResponse: Codable {
    let jsonrpc: String
    let result: String
    let id: Int
}

// Add JSON-RPC error response structure
struct JSONRPCErrorResponse: Codable {
    let jsonrpc: String
    let error: JSONRPCError
    let id: Int
}

struct JSONRPCError: Codable {
    let code: Int
    let message: String
}

// Add Transaction struct for the provider
struct Transaction: Codable {
    let to: String
    let value: String
    let from: String
} 
