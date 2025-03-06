import SwiftUI
import AVFoundation

struct PaymentRequestCard: View {
    let message: String
    let bleService: BLEService
    let onPaymentAction: (Bool) -> Void
    @StateObject private var privyService = PrivyService.shared
    @State private var paymentState: PaymentState = .initial
    @State private var rotationDegrees = 0.0
    
    enum PaymentState {
        case initial
        case processing
        case completed
        case failed
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 12) {
                Text("Payment Request")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if message.starts(with: "PAYMENT_REQUEST:") {
                    let components = message.split(separator: ":")
                    if components.count >= 3 {
                        Text("Amount: \(components[1]) MON")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.primary)
                        Text("From: \(components[2])")
                            .font(.subheadline)
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                        
                        // Display note if it exists (components[3])
                        if components.count >= 4 && !components[3].isEmpty {
                            Text("Note: \(components[3])")
                                .font(.subheadline)
                                .lineLimit(2)
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                        
                        switch paymentState {
                        case .initial:
                            HStack(spacing: 20) {
                                Button(action: {
                                    bleService.stopAdvertising() 
                                    bleService.sendPaymentResponse(approved: false)
                                    onPaymentAction(false)
                                }) {
                                    Text("Decline")
                                        .foregroundColor(.red)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 20)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    // Start payment flow
                                    withAnimation {
                                        paymentState = .processing
                                    }
                                    
                                    // Sound feedback like Apple Pay
                                    AudioServicesPlaySystemSound(1519) // Standard Apple Pay begin sound
                                    
                                    // Start rotation animation
                                    withAnimation(Animation.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                                        rotationDegrees = 360
                                    }
                                    
                                    // Process the transaction
                                    if let amount = Double(components[1]),
                                       let recipientAddress = String(components[2]) as String? {
                                        Task {
                                            do {
                                                try await privyService.sendTransaction(amount: amount, to: recipientAddress)
                                                
                                                // Success animation before completing
                                                withAnimation {
                                                    paymentState = .completed
                                                }
                                                
                                                // Wait for animation to complete
                                                try? await Task.sleep(nanoseconds: 800_000_000)
                                                
                                                // Notify payment complete
                                                bleService.stopAdvertising()
                                                bleService.sendPaymentResponse(approved: true)
                                                onPaymentAction(true)
                                            } catch {
                                                print("Error sending transaction: \(error)")

                                                // Failure animation
                                                withAnimation {
                                                    paymentState = .failed
                                                }
                                                
                                                // Wait for animation to complete
                                                try? await Task.sleep(nanoseconds: 800_000_000)
                                                
                                                // Notify payment failed
                                                bleService.stopAdvertising()
                                                bleService.sendPaymentResponse(approved: false)
                                                onPaymentAction(false)
                                            }
                                        }
                                    }
                                }) {
                                    Text("Pay")
                                        .foregroundColor(.white)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 20)
                                        .background(Color.blue)
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.top, 8)
                            
                        case .processing:
                            // True Apple Pay-like processing animation
                            ZStack {
                                // No need for additional background box in processing state
                                
                                // Proper Apple Pay-style animation
                                ZStack {
                                    // Static background circle
                                    Circle()
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 5)
                                        .frame(width: 70, height: 70)
                                    
                                    // Animated arc
                                    Circle()
                                        .trim(from: 0, to: 0.7)
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                        )
                                        .frame(width: 70, height: 70)
                                        .rotationEffect(Angle(degrees: rotationDegrees))
                                    
                                    // Pulse effect
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(width: 60, height: 60)
                                        .scaleEffect(1 + 0.1 * sin(Double(rotationDegrees) / 30))
                                }
                            }
                            .frame(height: 120)
                            .frame(maxWidth: .infinity)
                            
                        case .completed:
                            // Success animation
                            ZStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 70, height: 70)
                                    .shadow(color: Color.black.opacity(0.1), radius: 5)
                                
                                Image(systemName: "checkmark")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .transition(.scale.combined(with: .opacity))
                            .frame(height: 120)
                            .onAppear {
                                AudioServicesPlaySystemSound(1407) // Success sound
                            }
                            
                        case .failed:
                            // Error animation
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 70, height: 70)
                                    .shadow(color: Color.black.opacity(0.1), radius: 5)
                                
                                Image(systemName: "xmark")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .transition(.scale.combined(with: .opacity))
                            .frame(height: 120)
                            .onAppear {
                                AudioServicesPlaySystemSound(1073) // Error sound
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(width: geometry.size.width, height: nil)
            // Translucent background using materials - Apple Pay style
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            // This ensures proper vertical positioning
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}

#Preview {
    ZStack {
        // Add a background in the preview to better show the translucency
        LinearGradient(
            gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .edgesIgnoringSafeArea(.all)
        
        PaymentRequestCard(
            message: "PAYMENT_REQUEST:10:0x1234567890abcdef:Coffee",
            bleService: BLEService(),
            onPaymentAction: { _ in }
        )
        .frame(height: 300)
        .padding(.horizontal)
    }
} 