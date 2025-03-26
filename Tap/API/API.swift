import Foundation
import Combine

// MARK: - API Endpoints
enum APIEnvironment {
    case development
    case production
    
    var baseURL: String {
        switch self {
        case .development:
            return "http://127.0.0.1:8000"
        case .production:
            return "https://swipeit-backend-preprod-avfqggardqazfkdw.westeurope-01.azurewebsites.net"
        }
    }
}

// MARK: - API Errors
enum APIError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case serverError(Int, String)
    case unauthorized
    case tokenExpired
    case notAuthenticated
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let status, let message):
            return "Server error (\(status)): \(message)"
        case .unauthorized:
            return "Not authorized to access this resource"
        case .tokenExpired:
            return "Authentication token has expired"
        case .notAuthenticated:
            return "Not authenticated"
        }
    }
}

// MARK: - Response Models
struct ApiTestResponse: Decodable {
    let status: String
    let message: String
    let timestamp: String
}

struct UsernameResponse: Decodable {
    let username: String
    // Add any other profile fields your API returns
}

// Add these model structs
struct ProfileUpdateRequest: Encodable {
    let id: String
    let username: String
    let email: String?
    let twitter: String?
    let solanaWallet: String?
    let ethereumWallet: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case twitter
        case solanaWallet = "solanaWallet"
        case ethereumWallet = "ethereumWallet"
    }
}

struct ProfileUpdateResponse: Decodable {
    let success: Bool
    let data: UserProfileData
    
    // Add this to maintain compatibility with existing code
    var username: String {
        return data.username
    }
}

struct UserProfileData: Decodable {
    let id: String
    let email: String?
    let twitter: String?
    let username: String
    let solanaWallet: String?
    let ethereumWallet: String?
    let updatedAt: String
}

struct UsernameAvailabilityResponse: Decodable {
    let taken: Bool
}

// Add this near other request/response models
struct RejectPaymentRequestBody: Encodable {
    let request_id: String
}

// Add this near other request/response models
struct PayPaymentRequestBody: Encodable {
    let request_id: String
    let transaction_hash: String
}

// MARK: - API Service
class APIService {
    static let shared = APIService()
    
    private let environment: APIEnvironment = .production
    private let session: URLSession
    private let tokenRetrySubject = PassthroughSubject<Void, Never>()
    private var tokenRetrySubscription: AnyCancellable?
    
    private let P2P_BASE_URL = "https://payments-prod-gpg2ezhkdhatchd9.westeurope-01.azurewebsites.net"
    
    // Add this property to APIService
    private var isRefreshingToken = false
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30 // 30 seconds timeout
        self.session = URLSession(configuration: config)
        
        // Set up token retry subscriber
        tokenRetrySubscription = tokenRetrySubject
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                print("Token expired, initiating refresh")
                Task {
                    // You'd implement token refreshing here
                    // For now, just notify the user they need to log in again
                    await MainActor.run {
                        // Can display a notification or handle in UI
                        print("Session expired, please log in again")
                    }
                }
            }
    }
    
    // MARK: - Helper Methods
    
    private func getAuthToken() -> String? {
        if case .authenticated(let session) = PrivyService.shared.authState {
            return session.authToken
        }
        return nil
    }
    
    // Add this helper method to handle JWT token formatting
    private func getFormattedAuthToken() -> String? {
        if let token = getAuthToken() {
            return "Bearer \(token)"
        }
        return nil
    }
    
    private func buildRequest(for path: String, method: String, body: Data? = nil, requiresAuth: Bool = true) throws -> URLRequest {
        // Handle both full URLs and relative paths
        let urlString = path.hasPrefix("http") ? path : "\(environment.baseURL)\(path)"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if required
        if requiresAuth {
            guard let formattedToken = getFormattedAuthToken() else {
                print("Failed to get auth token for request to: \(path)")
                throw APIError.notAuthenticated
            }
            request.setValue(formattedToken, forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    // MARK: - HTTP Methods
    
    func get<T: Decodable>(path: String, requiresAuth: Bool = true, maxRetries: Int = 1) async throws -> T {
        try await performRequest(path: path, method: "GET", requiresAuth: requiresAuth, maxRetries: maxRetries)
    }
    
    func post<T: Decodable, U: Encodable>(path: String, body: U, requiresAuth: Bool = true, maxRetries: Int = 1) async throws -> T {
        let bodyData = try JSONEncoder().encode(body)
        return try await performRequest(path: path, method: "POST", body: bodyData, requiresAuth: requiresAuth, maxRetries: maxRetries)
    }
    
    func put<T: Decodable, U: Encodable>(path: String, body: U, requiresAuth: Bool = true, maxRetries: Int = 1) async throws -> T {
        let bodyData = try JSONEncoder().encode(body)
        return try await performRequest(path: path, method: "PUT", body: bodyData, requiresAuth: requiresAuth, maxRetries: maxRetries)
    }
    
    func delete<T: Decodable>(path: String, requiresAuth: Bool = true, maxRetries: Int = 1) async throws -> T {
        try await performRequest(path: path, method: "DELETE", requiresAuth: requiresAuth, maxRetries: maxRetries)
    }
    
    // MARK: - Main Request Method
    
    private func performRequest<T: Decodable>(path: String, method: String, body: Data? = nil, requiresAuth: Bool = true, retry: Int = 0, maxRetries: Int = 1) async throws -> T {
        do {
            let request = try buildRequest(for: path, method: method, body: body, requiresAuth: requiresAuth)
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    print("API: Decoding error: \(error)")
                    print("API: Response data: \(String(data: data, encoding: .utf8) ?? "Invalid data")")
                    throw APIError.decodingFailed(error)
                }
                
            case 401, 403:
                // Check if it's a token expiration
                if let responseString = String(data: data, encoding: .utf8),
                   responseString.contains("Token has expired") {
                    
                    if retry < maxRetries {
                        print("API: Token expired, attempting refresh...")
                        
                        // Get new token from PrivyService
                        let newToken = try await PrivyService.shared.refreshToken()
                        
                        print("API: Got new token, retrying request...")
                        // Retry the request with new token
                        return try await performRequest(
                            path: path,
                            method: method,
                            body: body,
                            requiresAuth: requiresAuth,
                            retry: retry + 1,
                            maxRetries: maxRetries
                        )
                    }
                }
                throw APIError.unauthorized
                
            default:
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.serverError(httpResponse.statusCode, message)
            }
        } catch {
            throw error
        }
    }
    
    // MARK: - Specific API Endpoints
    
    func testApiConnection() async throws -> ApiTestResponse {
        return try await get(path: "/api-test", requiresAuth: true)
    }
    
    // Alternative version that returns just the message
    func testApiConnectionMessage() async throws -> String {
        let response: ApiTestResponse = try await get(path: "/api-test", requiresAuth: true)
        return response.message
    }
    
    func getUserProfile(userId: String) async throws -> UsernameResponse {
        return try await get(path: "/profile/\(userId)", requiresAuth: true)
    }
    
    // Add more endpoint methods here based on your API needs
    
    // Add these methods to the APIService class
    func checkUsernameAvailability(username: String) async throws -> UsernameAvailabilityResponse {
        return try await get(path: "/profile/username/check/\(username)", requiresAuth: true)
    }
    
    func updateProfile(username: String) async throws -> ProfileUpdateResponse {
        // Get the user ID from PrivyService
        guard let userId = PrivyService.shared.getUserId() else {
            throw APIError.notAuthenticated
        }
        
        // Get the current auth state to extract email and wallet
        guard case .authenticated(let session) = PrivyService.shared.authState else {
            throw APIError.notAuthenticated
        }
        
        print("Linked accounts: \(session.user.linkedAccounts)")
        
        // Extract email from linked accounts with logging
        let email = session.user.linkedAccounts.first { account in
            if case .email = account {
                return true
            }
            return false
        }.flatMap { account in
            if case .email(let emailAccount) = account {
                print("Found email: \(emailAccount.email)")
                return emailAccount.email
            }
            return nil
        }
        
        // Extract Ethereum wallet with detailed logging
        let ethereumWallet = session.user.linkedAccounts.first { account in
            if case .embeddedWallet(let wallet) = account {
                print("Found wallet: \(wallet.address) of type \(wallet.chainType)")
                return wallet.chainType == .ethereum
            }
            return false
        }.flatMap { account in
            if case .embeddedWallet(let wallet) = account {
                print("Selected Ethereum wallet: \(wallet.address)")
                return wallet.address
            }
            return nil
        }
        
        // Create request with all available data
        let request = ProfileUpdateRequest(
            id: userId,
            username: username,
            email: email,
            twitter: nil,
            solanaWallet: nil,
            ethereumWallet: ethereumWallet
        )
        
        // Log the complete request object
        print("Profile update request details:")
        print("- ID: \(userId)")
        print("- Username: \(username)")
        print("- Email: \(email ?? "nil")")
        print("- Ethereum Wallet: \(ethereumWallet ?? "nil")")
        
        // Log the actual JSON that will be sent
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let jsonData = try? encoder.encode(request),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("\nRequest JSON:")
            print(jsonString)
        }
        
        // Make the API call
        let response: ProfileUpdateResponse = try await post(path: "/profile/update", body: request, requiresAuth: true)
        
        // Log the response
        print("\nResponse received:")
        print(response)
        
        return response
    }
    
    // Update the getUserProfiles method to be clean and consistent
    func getUserProfiles() async throws -> [UserProfile] {
        // Use the performRequest method instead of creating a new URLRequest
        let fullPath = "\(P2P_BASE_URL)/p2p/user-profiles"
        return try await performRequest(path: fullPath, method: "GET", requiresAuth: true)
    }
    
    func createPaymentRequest(friendId: String, amount: Decimal, note: String? = nil) async throws -> PaymentRequestResponse {
        let fullPath = "\(P2P_BASE_URL)/p2p/payment-request"
        let requestBody = CreatePaymentRequestBody(
            friendId: friendId,
            amount: amount,
            note: note
        )
        return try await post(path: fullPath, body: requestBody, requiresAuth: true)
    }
    
    func getReceivedPaymentRequests() async throws -> [PaymentRequestModel] {
        let fullPath = "\(P2P_BASE_URL)/p2p/payment-requests/received"
        return try await performRequest(path: fullPath, method: "GET", requiresAuth: true)
    }
    
    // Add this method to APIService class
    func rejectPaymentRequest(requestId: String) async throws -> EmptyResponse {
        let fullPath = "\(P2P_BASE_URL)/p2p/payment-request/reject"
        let requestBody = RejectPaymentRequestBody(request_id: requestId)
        return try await post(path: fullPath, body: requestBody, requiresAuth: true)
    }
    
    // Add this method to APIService class
    func payPaymentRequest(requestId: String, transactionHash: String) async throws -> EmptyResponse {
        let fullPath = "\(P2P_BASE_URL)/p2p/payment-request/pay"
        let requestBody = PayPaymentRequestBody(
            request_id: requestId,
            transaction_hash: transactionHash
        )
        return try await post(path: fullPath, body: requestBody, requiresAuth: true)
    }
}

// MARK: - Empty Response Types for endpoints with no return data
struct EmptyResponse: Decodable {} 
