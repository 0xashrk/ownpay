import SwiftUI
import PrivySDK

struct LoginView: View {
    @StateObject private var privyService = PrivyService.shared
    @State private var email = ""
    @State private var otpCode = ""
    @State private var showingOTPInput = false
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isLoggedIn = false
    
    var body: some View {
        Group {
            if !privyService.isReady {
                ProgressView("Initializing...")
            } else if isLoggedIn {
                ContentView()
                    .onDisappear {
                        // Reset state when user logs out
                        isLoggedIn = false
                        showingOTPInput = false
                        email = ""
                        otpCode = ""
                        errorMessage = nil
                    }
            } else {
                VStack(spacing: 20) {
                    Text("Welcome to Tap")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if !showingOTPInput {
                        // Email Input View
                        VStack(spacing: 16) {
                            TextField("Email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .textCase(.lowercase)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disabled(isLoading)
                            
                            Button(action: sendOTP) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Continue with Email")
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                            .disabled(isLoading || email.isEmpty)
                        }
                    } else {
                        // OTP Input View
                        VStack(spacing: 16) {
                            Text("Enter verification code")
                                .font(.headline)
                            
                            Text("We sent a code to \(email)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField("Code", text: $otpCode)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                                .disabled(isLoading)
                            
                            Button(action: verifyOTP) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Verify")
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                            .disabled(isLoading || otpCode.count != 6)
                            
                            Button(action: sendOTP) {
                                Text("Resend Code")
                                    .foregroundColor(.blue)
                            }
                            .disabled(isLoading)
                        }
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
            }
        }
        .onReceive(privyService.$authState) { state in
            print("Received auth state: \(state)")
            if case .authenticated = state {
                isLoggedIn = true
            }
        }
        .onReceive(privyService.$otpFlowState) { state in
            print("Received OTP flow state: \(state)")
            switch state {
            case .sendCodeFailure(let error):
                errorMessage = "Failed to send code: \(error?.localizedDescription ?? "Unknown error")"
                isLoading = false
            case .awaitingCodeInput:
                showingOTPInput = true
                isLoading = false
            case .incorrectCode:
                errorMessage = "Incorrect code. Please try again."
                isLoading = false
            case .loginError(let error):
                errorMessage = "Login error: \(error.localizedDescription)"
                isLoading = false
            case .done:
                isLoading = false
            default:
                break
            }
        }
    }
    
    private func sendOTP() {
        print("Sending OTP to: \(email)")
        isLoading = true
        errorMessage = nil
        
        Task {
            let success = await privyService.sendCode(to: email)
            if !success {
                DispatchQueue.main.async {
                    errorMessage = "Failed to send verification code. Please check your email and try again."
                    isLoading = false
                }
            }
        }
    }
    
    private func verifyOTP() {
        print("Verifying OTP: \(otpCode)")
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let authState = try await privyService.loginWithCode(otpCode, sentTo: email)
                print("Verification result: \(authState)")
            } catch {
                print("Verification error: \(error)")
                DispatchQueue.main.async {
                    errorMessage = "Verification failed: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    LoginView()
} 
