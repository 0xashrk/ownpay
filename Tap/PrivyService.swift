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
    @Published var defaultRecipientAddress: String = ""
    @Published var defaultAmount: Double = 2.0
    
    // Add this property to store the token
    @Published private(set) var accessToken: String?
    
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
    
    // Add this property to track pending balance requests
    private var balanceRequestTask: Task<Void, Never>?
    
    private init() {
        print("Initializing PrivyService with appId: \(Config.privyAppId)")
        print("Client ID: \(Config.privyClientId)")
        
        let config = PrivyConfig(appId: Config.privyAppId, appClientId: Config.privyClientId)
        privy = PrivySdk.initialize(config: config)
        
        // Set up auth state change callback
        privy.setAuthStateChangeCallback { [weak self] state in
            guard let self = self else { return }
            print("Auth state changed to: \(String(describing: type(of: state)))")
            
            DispatchQueue.main.async {
                self.authState = state
                
                // CRITICAL FIX: Always update isReady after SDK initialization
                if !self.isReady && state != .notReady {
                    self.isReady = true
                    print("PrivyService is now ready")
                }
                
                // When authenticated, store the token
                if case .authenticated(let session) = state {
                    self.accessToken = session.authToken
                    print("Access token received and stored: \(self.accessToken ?? "No token")")
                    
                    // Extract and print the user's Privy ID without the "did:privy:" prefix
                    let fullId = session.user.id
                    let userId = fullId.hasPrefix("did:privy:") ? String(fullId.dropFirst(10)) : fullId
                    print("User Privy ID: \(userId)")
                    let sample = session.user.linkedAccounts
                    print("Sample: \(sample) \nEnd")
                    
                    // Check if user has a wallet
                    let hasEthereumWallet = session.user.linkedAccounts.contains { account in
                        if case .embeddedWallet(let wallet) = account {
                            return wallet.chainType == .ethereum
                        }
                        return false
                    }
                    
                    if hasEthereumWallet {
                        // User already has a wallet, retrieve it
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
                                
                                // Get provider for this wallet
                                do {
                                    self.ethereumProvider = try self.privy.embeddedWallet.getEthereumProvider(for: wallet.address)
                                    print("Got ethereum provider for wallet")
                                    
                                    // Fetch balance
                                    Task {
                                        await self.fetchBalance()
                                    }
                                } catch {
                                    print("Error getting provider: \(error)")
                                }
                            }
                        }
                    } else {
                        // User doesn't have a wallet, create one automatically
                        print("User doesn't have an Ethereum wallet. Creating one automatically...")
                        self.embeddedWalletState = .connecting
                        
                        // Create wallet in background task to avoid blocking the auth callback
                        Task {
                            do {
                                // Create an Ethereum wallet based on the documentation
                                let wallet = try await self.privy.embeddedWallet.createWallet(chainType: .ethereum, allowAdditional: false)
                                
                                await MainActor.run {
                                    print("Wallet created successfully: \(wallet.address)")
                                    self.walletAddress = wallet.address
                                    self.embeddedWalletState = .connected(wallets: [Wallet(address: wallet.address)])
                                    
                                    // Get provider for the new wallet
                                    do {
                                        self.ethereumProvider = try self.privy.embeddedWallet.getEthereumProvider(for: wallet.address)
                                        print("Got ethereum provider for newly created wallet")
                                        
                                        // Fetch balance for the new wallet
                                        Task {
                                            await self.fetchBalance()
                                        }
                                    } catch {
                                        print("Error getting provider for new wallet: \(error)")
                                    }
                                }
                            } catch {
                                await MainActor.run {
                                    print("Error creating wallet: \(error)")
                                    self.embeddedWalletState = .notConnected
                                }
                            }
                        }
                    }
                } else {
                    // Clear token if not authenticated
                    self.accessToken = nil
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
        
        // Clear the user profile
        UserProfileService.shared.clearProfile()
        
        self.authState = .unauthenticated
        self.otpFlowState = .initial
        self.walletAddress = nil
        self.embeddedWalletState = .notConnected
        print("Logout successful")
    }
    
    @MainActor
    func fetchBalance() async {
        // Cancel any pending balance request
        balanceRequestTask?.cancel()
        
        // Create a new task for this request
        balanceRequestTask = Task {
            guard let address = walletAddress else {
                print("No wallet address available")
                self.balance = "No wallet"
                return
            }
            
            do {
                print("Fetching balance for address: \(address)")
                // Add a small delay to prevent rapid consecutive requests
                do {
                    try await Task.sleep(nanoseconds: 500_000_000) // 500ms
                } catch {
                    // If sleep is cancelled, just return without setting error state
                    print("Balance fetch delay was cancelled")
                    return
                }
                
                // Check if task was cancelled after the delay
                if Task.isCancelled { 
                    print("Balance fetch task was cancelled")
                    return
                }
                
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
                
                // Wrap the data task in a do-catch to handle cancellation separately
                do {
                    let (data, _) = try await URLSession.shared.data(for: request)
                    
                    if Task.isCancelled {
                        print("Task cancelled after data received, not updating UI")
                        return
                    }
                    
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
                    
                    let balance = hexToMON(hexString: balanceHex)
                    print("Converted balance: \(balance) MON")
                    
                    // Update balance on main thread with proper formatting
                    if !Task.isCancelled {
                        self.balance = String(format: "%.5f MON", balance)
                        self.monBalance = nil // Clear MON balance since it's the same as native balance
                        
                        // Force UI update
                        self.objectWillChange.send()
                    }
                } catch let urlError as URLError where urlError.code == .cancelled {
                    print("Network request was cancelled, not treating as error")
                    return
                }
            } catch is CancellationError {
                // Explicitly handle task cancellation
                print("Task was cancelled, not setting error state")
            } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == -999 {
                // Handle URL session cancellation
                print("Balance request was cancelled, this is normal if multiple requests were made")
            } catch {
                print("Error fetching balance: \(error)")
                print("Error details: \(String(describing: error))")
                
                // Only set error state if the task wasn't cancelled
                if !Task.isCancelled {
                    self.balance = "Error"
                    self.monBalance = nil
                }
            }
        }
        
        // Don't await task completion - this can cause UI to hang
        // Instead, let it run in the background
    }
    
    // Add this helper function if it doesn't exist
    private func hexToMON(hexString: String) -> Double {
        // Remove "0x" prefix if present
        let cleanHex = hexString.hasPrefix("0x") ? String(hexString.dropFirst(2)) : hexString
        
        // Convert hex to decimal string manually (handling arbitrary size)
        var decimalValue: Decimal = 0
        for char in cleanHex {
            let digitValue: UInt8
            switch char.lowercased() {
            case "0"..."9": 
                digitValue = UInt8(String(char))!
            case "a"..."f": 
                digitValue = UInt8(char.asciiValue! - Character("a").asciiValue! + 10)
            default:
                continue
            }
            decimalValue = decimalValue * 16 + Decimal(digitValue)
        }
        
        // Divide by 10^18 to get MON value
        let divisor = pow(Decimal(10), 18)
        let monValue = decimalValue / divisor
        
        return NSDecimalNumber(decimal: monValue).doubleValue
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
    func sendTransaction(amount: Double, to recipientAddress: String) async throws -> String {
        guard case .connected(let wallets) = privy.embeddedWallet.embeddedWalletState else {
            print("Wallet not connected")
            throw WalletError.providerNotInitialized
        }

        guard let wallet = wallets.first, wallet.chainType == .ethereum else {
            print("No Ethereum wallets available")
            throw WalletError.providerNotInitialized
        }

        do {
            let provider = try privy.embeddedWallet.getEthereumProvider(for: wallet.address)
            
            // Step 1: Get the nonce from our configured RPC endpoint
            let nonce = try await getTransactionCount(address: wallet.address)
            print("Got nonce from RPC: \(nonce)")
            
            // Convert amount to wei (1 MON = 1e18 wei)
            let amountInWei = UInt64(amount * 1e18)
            
            // Create transaction with EIP-1559 gas parameters
            let tx: [String: Any] = [
                "from": wallet.address,
                "to": recipientAddress,
                "value": toHexString(amountInWei),
                "chainId": "0x279f",
                "gas": toHexString(21000),
                "maxFeePerGas": toHexString(500000000000),
                "maxPriorityFeePerGas": toHexString(20000000000),
                "nonce": nonce
            ]
            
            print("Preparing transaction: \(tx)")
            
            let txData = try JSONSerialization.data(withJSONObject: tx)
            let txString = String(data: txData, encoding: .utf8)!
            
            // Sign the transaction using Privy SDK
            let signedTx = try await provider.request(
                RpcRequest(
                    method: "eth_signTransaction",
                    params: [txString]
                )
            )

            guard let signedTxString = signedTx as? String else {
                throw WalletError.rpcError("Failed to sign transaction")
            }
            
            print("Transaction signed successfully: \(signedTxString)")
            
            // Send the raw transaction and get the transaction hash
            let txHash = try await sendRawTransaction(signedTx: signedTxString)
            print("Transaction submitted with hash: \(txHash)")
            
            // Wait for transaction confirmation
            try await Task.sleep(nanoseconds: 3 * 1_000_000_000) // 3 seconds
            await fetchBalance()
            
            return txHash // Return the actual transaction hash
        } catch {
            print("Error sending transaction: \(error)")
            throw error
        }
    }
    
    // New helper method to get transaction count (nonce)
    func getTransactionCount(address: String) async throws -> String {
        let url = URL(string: monadRPCURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let rpcRequest: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_getTransactionCount",
            "params": [address, "pending"],
            "id": 1
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: rpcRequest)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // First try to decode as error response
        if let errorResponse = try? JSONDecoder().decode(JSONRPCErrorResponse.self, from: data) {
            print("RPC Error: \(errorResponse.error.message)")
            throw WalletError.rpcError(errorResponse.error.message)
        }
        
        // If not an error, decode as success response
        let response = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
        return response.result
    }
    
    // New helper method to send raw transaction
    func sendRawTransaction(signedTx: String) async throws -> String {
        let url = URL(string: monadRPCURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let rpcRequest: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_sendRawTransaction",
            "params": [signedTx],
            "id": 1
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: rpcRequest)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // First try to decode as error response
        if let errorResponse = try? JSONDecoder().decode(JSONRPCErrorResponse.self, from: data) {
            print("RPC Error: \(errorResponse.error.message)")
            throw WalletError.rpcError(errorResponse.error.message)
        }
        
        // If not an error, decode as success response
        let response = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
        return response.result
    }
    
    // Add this helper function
    private func toHexString(_ number: UInt64) -> String {
        return "0x" + String(format: "%llx", number)
    }
    
    // Add this convenient method to get the token
    func getAccessToken() -> String? {
        if case .authenticated(let session) = authState {
            return session.authToken
        }
        return accessToken
    }
    
    // Update this method to PrivyService class to return the ID without the prefix
    func getUserId() -> String? {
        if case .authenticated(let session) = authState {
            let fullId = session.user.id
            return fullId.hasPrefix("did:privy:") ? String(fullId.dropFirst(10)) : fullId
        }
        return nil
    }
    
    // Add this method to explicitly create a wallet for the user
    @MainActor
    func createEthereumWalletIfNeeded() async {
        print("Checking if user needs an Ethereum wallet...")
        
        if walletAddress != nil {
            print("User already has a wallet, skipping creation")
            return
        }
        
        guard case .authenticated = authState else {
            print("User not authenticated, cannot create wallet")
            return
        }
        
        print("No wallet found, creating new Ethereum wallet...")
        self.embeddedWalletState = .connecting
        
        do {
            // This is the correct API call according to Privy docs
            let wallet = try await privy.embeddedWallet.createWallet(chainType: .ethereum, allowAdditional: false)
            
            print("✅ Wallet created successfully: \(wallet.address)")
            self.walletAddress = wallet.address
            self.embeddedWalletState = .connected(wallets: [Wallet(address: wallet.address)])
            
            // Get provider for the new wallet
            do {
                self.ethereumProvider = try self.privy.embeddedWallet.getEthereumProvider(for: wallet.address)
                print("Got ethereum provider for newly created wallet")
                
                // Fetch balance for the new wallet
                await self.fetchBalance()
            } catch {
                print("Error getting provider for new wallet: \(error)")
            }
        } catch {
            print("Error creating wallet: \(error)")
            self.embeddedWalletState = .notConnected
        }
    }
    
    @MainActor
    func refreshToken() async throws {
        print("Attempting to refresh token...")
        
        // First check if we're already authenticated
        guard case .authenticated = authState else {
            print("Not authenticated, cannot refresh token")
            throw APIError.notAuthenticated
        }
        
        do {
            // Re-initialize the SDK to force a new token
            let config = PrivyConfig(appId: Config.privyAppId, appClientId: Config.privyClientId)
            privy = PrivySdk.initialize(config: config)
            
            // Wait for the new auth state with timeout
            let startTime = Date()
            while Date().timeIntervalSince(startTime) < 5.0 { // 5 second timeout
                if case .authenticated(let session) = authState {
                    self.accessToken = session.authToken
                    print("Successfully refreshed token: \(session.authToken)")
                    
                    // Force a balance refresh after token update
                    await fetchBalance()
                    return
                }
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms
            }
            
            print("Token refresh timed out")
            throw APIError.tokenExpired
        } catch {
            print("Failed to refresh token: \(error)")
            // If refresh fails, log out the user
            try await logout()
            throw APIError.tokenExpired
        }
    }
}
