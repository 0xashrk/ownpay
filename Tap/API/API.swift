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

// MARK: - API Service
class APIService {
    static let shared = APIService()
    
    private let environment: APIEnvironment = .production
    private let session: URLSession
    private let tokenRetrySubject = PassthroughSubject<Void, Never>()
    private var tokenRetrySubscription: AnyCancellable?
    
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
    
    private func buildRequest(for path: String, method: String, body: Data? = nil, requiresAuth: Bool = true) throws -> URLRequest {
        guard let url = URL(string: "\(environment.baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if required
        if requiresAuth {
            guard let token = getAuthToken() else {
                throw APIError.notAuthenticated
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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
            
            // Handle response status
            switch httpResponse.statusCode {
            case 200...299:
                // Success!
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    print("Decoding error: \(error)")
                    print("Response data: \(String(data: data, encoding: .utf8) ?? "Invalid data")")
                    throw APIError.decodingFailed(error)
                }
                
            case 401:
                // Unauthorized
                if let responseString = String(data: data, encoding: .utf8),
                   responseString.contains("Token has expired") && retry < maxRetries {
                    // Token expired - notify token refresh system
                    tokenRetrySubject.send()
                    
                    // Wait a bit for potential token refresh
                    try await Task.sleep(for: .seconds(1))
                    
                    // Retry the request
                    return try await performRequest(path: path, method: method, body: body, requiresAuth: requiresAuth, retry: retry + 1, maxRetries: maxRetries)
                }
                
                throw APIError.unauthorized
                
            case 403:
                // Forbidden
                throw APIError.unauthorized
                
            default:
                // Other error
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.serverError(httpResponse.statusCode, message)
            }
            
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.requestFailed(error)
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
        
        // Create request with both id and username
        let request = ProfileUpdateRequest(
            id: userId, 
            username: username
        )
        
        // Log the request for debugging
        print("Profile update request: \(userId), \(username)")
        
        // Make the API call
        let response: ProfileUpdateResponse = try await post(path: "/profile/update", body: request, requiresAuth: true)
        
        // Log the response for debugging
        print("Profile update response: \(response)")
        
        return response
    }
}

// MARK: - Empty Response Types for endpoints with no return data
struct EmptyResponse: Decodable {} 
