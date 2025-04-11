import Foundation

enum TransactionVerificationError: Error {
    case transactionFailed
    case transactionReverted
    case timeout
    case rpcError(String)
    case invalidResponse
}

class TransactionVerifier {
    private let rpcURL: String
    private let maxRetries: Int
    private let retryDelay: TimeInterval
    
    init(rpcURL: String, maxRetries: Int = 10, retryDelay: TimeInterval = 2.0) {
        self.rpcURL = rpcURL
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
    }
    
    func verifyTransaction(txHash: String, senderAddress: String, recipientAddress: String, expectedAmount: UInt64) async throws -> Bool {
        // First verify the transaction was successful
        let receipt = try await getTransactionReceipt(txHash: txHash)
        
        guard receipt.status == "0x1" else {
            throw TransactionVerificationError.transactionReverted
        }
        
        // Then verify the recipient's balance increased
        let recipientBalance = try await getBalance(address: recipientAddress)
        
        // Get the transaction details to verify the amount
        let txDetails = try await getTransactionByHash(txHash: txHash)
        
        // Convert hex values to numbers
        let actualAmount = hexToDecimal(txDetails.value)
        
        // Verify the amount matches
        guard actualAmount == expectedAmount else {
            throw TransactionVerificationError.invalidResponse
        }
        
        return true
    }
    
    private func getTransactionReceipt(txHash: String) async throws -> TransactionReceipt {
        let request = createRPCRequest(method: "eth_getTransactionReceipt", params: [txHash])
        let response: JSONRPCResponse<TransactionReceipt> = try await sendRPCRequest(request)
        return response.result
    }
    
    private func getTransactionByHash(txHash: String) async throws -> Transaction {
        let request = createRPCRequest(method: "eth_getTransactionByHash", params: [txHash])
        let response: JSONRPCResponse<Transaction> = try await sendRPCRequest(request)
        return response.result
    }
    
    private func getBalance(address: String) async throws -> UInt64 {
        let request = createRPCRequest(method: "eth_getBalance", params: [address, "latest"])
        let response: JSONRPCResponse<String> = try await sendRPCRequest(request)
        return hexToDecimal(response.result)
    }
    
    private func createRPCRequest(method: String, params: [Any]) -> [String: Any] {
        return [
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "id": 1
        ]
    }
    
    private func sendRPCRequest<T: Decodable>(_ request: [String: Any]) async throws -> JSONRPCResponse<T> {
        let url = URL(string: rpcURL)!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: request)
        
        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        
        // First try to decode as error response
        if let errorResponse = try? JSONDecoder().decode(JSONRPCErrorResponse.self, from: data) {
            throw TransactionVerificationError.rpcError(errorResponse.error.message)
        }
        
        return try JSONDecoder().decode(JSONRPCResponse<T>.self, from: data)
    }
    
    private func hexToDecimal(_ hexString: String) -> UInt64 {
        let cleanHex = hexString.hasPrefix("0x") ? String(hexString.dropFirst(2)) : hexString
        return UInt64(cleanHex, radix: 16) ?? 0
    }
}

// Supporting types
struct TransactionReceipt: Codable {
    let status: String
    let transactionHash: String
    let blockNumber: String
    let from: String
    let to: String
    let gasUsed: String
}

struct Transaction: Codable {
    let hash: String
    let from: String
    let to: String
    let value: String
    let gas: String
    let gasPrice: String
    let nonce: String
    let input: String
    let v: String
    let r: String
    let s: String
    
    enum CodingKeys: String, CodingKey {
        case hash = "hash"
        case from = "from"
        case to = "to"
        case value = "value"
        case gas = "gas"
        case gasPrice = "gasPrice"
        case nonce = "nonce"
        case input = "input"
        case v = "v"
        case r = "r"
        case s = "s"
    }
}

struct JSONRPCResponse<T: Codable>: Codable {
    let jsonrpc: String
    let result: T
    let id: Int
}

struct JSONRPCErrorResponse: Codable {
    let jsonrpc: String
    let error: JSONRPCError
    let id: Int
}

struct JSONRPCError: Codable {
    let code: Int
    let message: String
} 