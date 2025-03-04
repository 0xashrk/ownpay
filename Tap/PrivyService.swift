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
    private let monadRPCURL = "https://testnet-rpc.monad.xyz"
    
    // Add MON token contract address for Monad testnet
    private let monTokenAddress = "0xB5a30b0FDc5EA94A52fDc42e3E9760Cb8449Fb37" // Replace with actual MON token address
    
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
                        
                        // Configure provider to use Monad testnet
                        do {
                            print("Attempting to switch to Monad testnet...")
                            let switchParams = try JSONSerialization.data(withJSONObject: [["chainId": "0x279f"]])
                            let switchParamsString = String(data: switchParams, encoding: .utf8)!
                            print("Switch params: \(switchParamsString)")
                            do {
                                _ = try await ethereumProvider?.request(
                                    RpcRequest(
                                        method: "wallet_switchEthereumChain",
                                        params: [switchParamsString]
                                    )
                                )
                                print("Successfully switched to Monad testnet")
                            } catch let error as WalletError {
                                print("Wallet error during chain switch: \(error)")
                                throw error
                            } catch {
                                print("Unexpected error during chain switch: \(error)")
                                print("Error description: \(error.localizedDescription)")
                                print("Error domain: \(error._domain)")
                                print("Error code: \(error._code)")
                                throw WalletError.rpcError("Chain switch failed: \(error.localizedDescription)")
                            }
                        } catch {
                            print("Error switching chain: \(error)")
                            print("Error details: \(String(describing: error))")
                            print("Attempting to add chain...")
                            // If chain not added, add it first
                            let chainParams: [String: Any] = [
                                "chainId": "0x279f",
                                "chainName": "Monad Testnet",
                                "nativeCurrency": [
                                    "name": "MON",
                                    "symbol": "MON",
                                    "decimals": 18
                                ],
                                "rpcUrls": ["https://testnet-rpc.monad.xyz"],
                                "blockExplorerUrls": ["https://testnet-explorer.monad.xyz"],
                                "iconUrls": ["https://testnet-explorer.monad.xyz/favicon.ico"]
                            ]
                            let addParams = try JSONSerialization.data(withJSONObject: [chainParams])
                            let addParamsString = String(data: addParams, encoding: .utf8)!
                            print("Add chain params: \(addParamsString)")
                            
                            do {
                                do {
                                    _ = try await ethereumProvider?.request(
                                        RpcRequest(
                                            method: "wallet_addEthereumChain",
                                            params: [addParamsString]
                                        )
                                    )
                                    print("Successfully added Monad testnet")
                                    
                                    // Now try switching again
                                    let switchParams = try JSONSerialization.data(withJSONObject: [["chainId": "0x279f"]])
                                    let switchParamsString = String(data: switchParams, encoding: .utf8)!
                                    print("Switch params (after add): \(switchParamsString)")
                                    do {
                                        _ = try await ethereumProvider?.request(
                                            RpcRequest(
                                                method: "wallet_switchEthereumChain",
                                                params: [switchParamsString]
                                            )
                                        )
                                        print("Successfully switched to Monad testnet")
                                    } catch let error as WalletError {
                                        print("Wallet error during second chain switch: \(error)")
                                        throw error
                                    } catch {
                                        print("Unexpected error during second chain switch: \(error)")
                                        print("Error description: \(error.localizedDescription)")
                                        print("Error domain: \(error._domain)")
                                        print("Error code: \(error._code)")
                                        throw WalletError.rpcError("Second chain switch failed: \(error.localizedDescription)")
                                    }
                                } catch let error as WalletError {
                                    print("Wallet error during chain add: \(error)")
                                    throw error
                                } catch {
                                    print("Unexpected error during chain add: \(error)")
                                    print("Error description: \(error.localizedDescription)")
                                    print("Error domain: \(error._domain)")
                                    print("Error code: \(error._code)")
                                    throw WalletError.rpcError("Chain add failed: \(error.localizedDescription)")
                                }
                            } catch {
                                print("Error adding/switching chain: \(error)")
                                print("Error details: \(String(describing: error))")
                                throw error
                            }
                        }
                        
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
                    
                    // Configure provider to use Monad testnet
                    do {
                        print("Attempting to switch to Monad testnet...")
                        let switchParams = try JSONSerialization.data(withJSONObject: [["chainId": "0x279f"]])
                        let switchParamsString = String(data: switchParams, encoding: .utf8)!
                        print("Switch params: \(switchParamsString)")
                        do {
                            _ = try await ethereumProvider?.request(
                                RpcRequest(
                                    method: "wallet_switchEthereumChain",
                                    params: [switchParamsString]
                                )
                            )
                            print("Successfully switched to Monad testnet")
                        } catch let error as WalletError {
                            print("Wallet error during chain switch: \(error)")
                            throw error
                        } catch {
                            print("Unexpected error during chain switch: \(error)")
                            print("Error description: \(error.localizedDescription)")
                            print("Error domain: \(error._domain)")
                            print("Error code: \(error._code)")
                            throw WalletError.rpcError("Chain switch failed: \(error.localizedDescription)")
                        }
                    } catch {
                        print("Error switching chain: \(error)")
                        print("Error details: \(String(describing: error))")
                        print("Attempting to add chain...")
                        // If chain not added, add it first
                        let chainParams: [String: Any] = [
                            "chainId": "0x279f",
                            "chainName": "Monad Testnet",
                            "nativeCurrency": [
                                "name": "MON",
                                "symbol": "MON",
                                "decimals": 18
                            ],
                            "rpcUrls": ["https://testnet-rpc.monad.xyz"],
                            "blockExplorerUrls": ["https://testnet-explorer.monad.xyz"],
                            "iconUrls": ["https://testnet-explorer.monad.xyz/favicon.ico"]
                        ]
                        let addParams = try JSONSerialization.data(withJSONObject: [chainParams])
                        let addParamsString = String(data: addParams, encoding: .utf8)!
                        print("Add chain params: \(addParamsString)")
                        
                        do {
                            do {
                                _ = try await ethereumProvider?.request(
                                    RpcRequest(
                                        method: "wallet_addEthereumChain",
                                        params: [addParamsString]
                                    )
                                )
                                print("Successfully added Monad testnet")
                                
                                // Now try switching again
                                let switchParams = try JSONSerialization.data(withJSONObject: [["chainId": "0x279f"]])
                                let switchParamsString = String(data: switchParams, encoding: .utf8)!
                                print("Switch params (after add): \(switchParamsString)")
                                do {
                                    _ = try await ethereumProvider?.request(
                                        RpcRequest(
                                            method: "wallet_switchEthereumChain",
                                            params: [switchParamsString]
                                        )
                                    )
                                    print("Successfully switched to Monad testnet")
                                } catch let error as WalletError {
                                    print("Wallet error during second chain switch: \(error)")
                                    throw error
                                } catch {
                                    print("Unexpected error during second chain switch: \(error)")
                                    print("Error description: \(error.localizedDescription)")
                                    print("Error domain: \(error._domain)")
                                    print("Error code: \(error._code)")
                                    throw WalletError.rpcError("Second chain switch failed: \(error.localizedDescription)")
                                }
                            } catch let error as WalletError {
                                print("Wallet error during chain add: \(error)")
                                throw error
                            } catch {
                                print("Unexpected error during chain add: \(error)")
                                print("Error description: \(error.localizedDescription)")
                                print("Error domain: \(error._domain)")
                                print("Error code: \(error._code)")
                                throw WalletError.rpcError("Chain add failed: \(error.localizedDescription)")
                            }
                        } catch {
                            print("Error adding/switching chain: \(error)")
                            print("Error details: \(String(describing: error))")
                            throw error
                        }
                    }
                    
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
                
                // Configure provider to use Monad testnet
                do {
                    print("Attempting to switch to Monad testnet...")
                    let switchParams = try JSONSerialization.data(withJSONObject: [["chainId": "0x279f"]])
                    let switchParamsString = String(data: switchParams, encoding: .utf8)!
                    print("Switch params: \(switchParamsString)")
                    do {
                        _ = try await ethereumProvider?.request(
                            RpcRequest(
                                method: "wallet_switchEthereumChain",
                                params: [switchParamsString]
                            )
                        )
                        print("Successfully switched to Monad testnet")
                    } catch let error as WalletError {
                        print("Wallet error during chain switch: \(error)")
                        throw error
                    } catch {
                        print("Unexpected error during chain switch: \(error)")
                        print("Error description: \(error.localizedDescription)")
                        print("Error domain: \(error._domain)")
                        print("Error code: \(error._code)")
                        throw WalletError.rpcError("Chain switch failed: \(error.localizedDescription)")
                    }
                } catch {
                    print("Error switching chain: \(error)")
                    print("Error details: \(String(describing: error))")
                    print("Attempting to add chain...")
                    // If chain not added, add it first
                    let chainParams: [String: Any] = [
                        "chainId": "0x279f",
                        "chainName": "Monad Testnet",
                        "nativeCurrency": [
                            "name": "MON",
                            "symbol": "MON",
                            "decimals": 18
                        ],
                        "rpcUrls": ["https://testnet-rpc.monad.xyz"],
                        "blockExplorerUrls": ["https://testnet-explorer.monad.xyz"],
                        "iconUrls": ["https://testnet-explorer.monad.xyz/favicon.ico"]
                    ]
                    let addParams = try JSONSerialization.data(withJSONObject: [chainParams])
                    let addParamsString = String(data: addParams, encoding: .utf8)!
                    print("Add chain params: \(addParamsString)")
                    
                    do {
                        do {
                            _ = try await ethereumProvider?.request(
                                RpcRequest(
                                    method: "wallet_addEthereumChain",
                                    params: [addParamsString]
                                )
                            )
                            print("Successfully added Monad testnet")
                            
                            // Now try switching again
                            let switchParams = try JSONSerialization.data(withJSONObject: [["chainId": "0x279f"]])
                            let switchParamsString = String(data: switchParams, encoding: .utf8)!
                            print("Switch params (after add): \(switchParamsString)")
                            do {
                                _ = try await ethereumProvider?.request(
                                    RpcRequest(
                                        method: "wallet_switchEthereumChain",
                                        params: [switchParamsString]
                                    )
                                )
                                print("Successfully switched to Monad testnet")
                            } catch let error as WalletError {
                                print("Wallet error during second chain switch: \(error)")
                                throw error
                            } catch {
                                print("Unexpected error during second chain switch: \(error)")
                                print("Error description: \(error.localizedDescription)")
                                print("Error domain: \(error._domain)")
                                print("Error code: \(error._code)")
                                throw WalletError.rpcError("Second chain switch failed: \(error.localizedDescription)")
                            }
                        } catch let error as WalletError {
                            print("Wallet error during chain add: \(error)")
                            throw error
                        } catch {
                            print("Unexpected error during chain add: \(error)")
                            print("Error description: \(error.localizedDescription)")
                            print("Error domain: \(error._domain)")
                            print("Error code: \(error._code)")
                            throw WalletError.rpcError("Chain add failed: \(error.localizedDescription)")
                        }
                    } catch {
                        print("Error adding/switching chain: \(error)")
                        print("Error details: \(String(describing: error))")
                        throw error
                    }
                }
                
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
    func sendMon(to recipientAddress: String? = nil, amount: Double? = nil) async {
        do {
            // Use provided values or defaults
            let finalRecipientAddress = recipientAddress ?? defaultRecipientAddress
            let finalAmount = amount ?? defaultAmount
            
            // First ensure wallet is connected
            if case .notConnected = embeddedWalletState {
                print("Wallet not connected, attempting to connect...")
                await connectWallet()
            }
            
            guard let address = walletAddress else {
                print("No wallet address available")
                return
            }
            
            // Get provider if not already initialized
            if ethereumProvider == nil {
                print("Provider not initialized, getting provider for wallet: \(address)")
                ethereumProvider = try privy.embeddedWallet.getEthereumProvider(for: address)
            }
            
            guard let provider = ethereumProvider else {
                print("Failed to initialize provider")
                return
            }
            
            print("Sending \(finalAmount) MON to \(finalRecipientAddress)")
            
            // Convert MON amount to wei (1 MON = 1e18 wei)
            let weiAmount = UInt64(finalAmount * 1e18)
            
            // Create transaction data
            let tx = try JSONEncoder().encode([
                "value": "0x" + String(weiAmount, radix: 16), // wei value in hex format
                "to": finalRecipientAddress, // destination address
                "chainId": "0x279f", // Monad testnet chainId
                "from": address, // sender's address
                "gas": "0x5208", // 21000 gas limit
                "maxFeePerGas": "0x59682f00", // 1.5 Gwei
                "maxPriorityFeePerGas": "0x59682f00" // 1.5 Gwei
            ])
            
            guard let txString = String(data: tx, encoding: .utf8) else {
                print("Failed to encode transaction data")
                return
            }
            
            print("Sending transaction with data: \(txString)")
            
            // Ensure we're on the correct chain
            let switchParams = try JSONSerialization.data(withJSONObject: [["chainId": "0x279f"]])
            let switchParamsString = String(data: switchParams, encoding: .utf8)!
            print("Switch params (before transaction): \(switchParamsString)")
            do {
                _ = try await provider.request(
                    RpcRequest(
                        method: "wallet_switchEthereumChain",
                        params: [switchParamsString]
                    )
                )
            } catch let error as WalletError {
                print("Wallet error during pre-transaction chain switch: \(error)")
                throw error
            } catch {
                print("Unexpected error during pre-transaction chain switch: \(error)")
                throw WalletError.rpcError("Pre-transaction chain switch failed: \(error.localizedDescription)")
            }
            
            // Send transaction using eth_sendTransaction
            do {
                let transactionHash = try await provider.request(
                    RpcRequest(
                        method: "eth_sendTransaction",
                        params: [txString]
                    )
                )
                print("Transaction sent successfully: \(transactionHash)")
            } catch let error as WalletError {
                print("Wallet error during transaction: \(error)")
                throw error
            } catch {
                print("Unexpected error during transaction: \(error)")
                throw WalletError.rpcError("Transaction failed: \(error.localizedDescription)")
            }
            
            // Refresh balance after sending
            await fetchBalance()
        } catch {
            print("Error sending transaction: \(error)")
            print("Error details: \(String(describing: error))")
            // Try to reconnect wallet on error
            await connectWallet()
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
