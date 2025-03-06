func sendPaymentResponse(approved: Bool) {
    // Create and send payment response message
    let message = "PAYMENT_RESPONSE:\(approved ? "APPROVED" : "DECLINED")"
    sendMessage(message)
    
    // ... rest of the code ...
} 