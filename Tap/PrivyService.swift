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
        guard let address = walletAddress else {
            print("No wallet address available")
            self.balance = "No wallet"
            return
        }
        
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
            
            // Update balance on main thread
            self.balance = String(format: "%.4f MON", balance)
            self.monBalance = nil // Clear MON balance since it's the same as native balance
            
            // Force UI update
            await MainActor.run {
                self.objectWillChange.send()
            }
        } catch {
            print("Error fetching balance: \(error)")
            print("Error details: \(String(describing: error))")
            self.balance = "Error"
            self.monBalance = nil
        }
    }
    
    // Add a refresh function that can be called from the UI
    @MainActor
    func refreshBalance() async {
        print("Refreshing balance...")
        // Add a small delay to ensure network has processed any pending transactions
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000) // 1 second
        await fetchBalance()
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

        // Function to get the current nonce
        func getCurrentNonce() async throws -> String {
            let provider = try privy.embeddedWallet.getEthereumProvider(for: wallet.address)
            let nonceResponse = try await provider.request(
                RpcRequest(
                    method: "eth_getTransactionCount",
                    params: [wallet.address, "latest"]
                )
            )
            
            if let response = nonceResponse as? [String: Any],
               let result = response["result"] as? String {
                return result
            }
            return "0x0"
        }

        // Function to send transaction with a specific nonce
        func sendTransactionWithNonce(_ nonce: String) async throws -> String {
            let provider = try privy.embeddedWallet.getEthereumProvider(for: wallet.address)
            
            // Create transaction object with EIP-1559 parameters
            let tx = [
                "value": toHexString(2000000000000000000), // 2.0 MON in wei
                "to": defaultRecipientAddress, // Send directly to recipient address
                "chainId": "0x279f", // Monad testnet chainId
                "from": wallet.address, // logged in user's embedded wallet address
                "gas": toHexString(21000), // Standard gas limit for native token transfer
                "maxFeePerGas": toHexString(52000000000), // 52 Gwei
                "maxPriorityFeePerGas": toHexString(52000000000), // 52 Gwei
                "nonce": nonce
            ]

            // Convert transaction to JSON string
            let txData = try JSONSerialization.data(withJSONObject: tx)
            guard let txString = String(data: txData, encoding: .utf8) else {
                print("Failed to convert transaction to string")
                throw WalletError.providerNotInitialized
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
                throw WalletError.providerNotInitialized
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
            return response.result
        }

        // Get initial nonce
        var currentNonce = try await getCurrentNonce()
        print("Initial nonce: \(currentNonce)")

        // Try to send transaction with retries for nonce errors
        var maxRetries = 3
        while maxRetries > 0 {
            do {
                let txHash = try await sendTransactionWithNonce(currentNonce)
                print("Transaction sent successfully: \(txHash)")
                
                // Wait a short delay to allow the transaction to be processed
                try await Task.sleep(nanoseconds: 2 * 1_000_000_000) // 2 seconds
                
                // Refresh the balance after successful transaction
                await fetchBalance()
                return
            } catch WalletError.rpcError(let message) where message.contains("Nonce too low") {
                // Extract the next nonce from the error message
                if let nextNonce = message.components(separatedBy: "next nonce ").last?.components(separatedBy: ",").first {
                    print("Retrying with next nonce: \(nextNonce)")
                    currentNonce = "0x\(String(Int(nextNonce) ?? 0, radix: 16))"
                    maxRetries -= 1
                } else {
                    throw WalletError.rpcError(message)
                }
            } catch {
                throw error
            }
        }
        
        throw WalletError.rpcError("Failed to send transaction after multiple nonce retries")
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
