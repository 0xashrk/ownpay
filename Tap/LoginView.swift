import SwiftUI

struct LoginView: View {
    @StateObject private var privyService = PrivyService.shared
    @State private var email = ""
    @State private var otpCode = ""
    @State private var showingOTPInput = false
    @State private var errorMessage: String?
    @State private var isLoading = false
    @Binding var isLoggedIn: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Tap")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if !showingOTPInput {
                // Email Input View
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
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
            }
            
            // OTP Flow State Indicator
            switch privyService.otpFlowState {
            case .sendingCode:
                Text("Sending code...")
                    .foregroundColor(.secondary)
            case .awaitingCodeInput:
                Text("Waiting for code...")
                    .foregroundColor(.secondary)
            case .submittingCode:
                Text("Verifying code...")
                    .foregroundColor(.secondary)
            case .incorrectCode:
                Text("Incorrect code. Please try again.")
                    .foregroundColor(.red)
            case .loginError(let error):
                Text("Error: \(error.localizedDescription)")
                    .foregroundColor(.red)
            default:
                EmptyView()
            }
        }
        .padding()
        .onAppear {
            setupOTPFlowStateCallback()
        }
    }
    
    private func setupOTPFlowStateCallback() {
        privyService.setOtpFlowStateChangeCallback { state in
            DispatchQueue.main.async {
                switch state {
                case .sendCodeFailure(let error):
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                case .awaitingCodeInput:
                    self.showingOTPInput = true
                    self.isLoading = false
                case .incorrectCode:
                    self.errorMessage = "Incorrect code. Please try again."
                    self.isLoading = false
                case .loginError(let error):
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                case .done:
                    self.isLoggedIn = true
                default:
                    break
                }
            }
        }
    }
    
    private func sendOTP() {
        isLoading = true
        errorMessage = nil
        
        Task {
            let success = await privyService.sendCode(to: email)
            if !success {
                DispatchQueue.main.async {
                    errorMessage = "Failed to send verification code. Please try again."
                    isLoading = false
                }
            }
        }
    }
    
    private func verifyOTP() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let authState = try await privyService.loginWithCode(otpCode, sentTo: email)
                if case .authenticated(_) = authState {
                    DispatchQueue.main.async {
                        isLoggedIn = true
                    }
                } else {
                    DispatchQueue.main.async {
                        errorMessage = "Authentication failed. Please try again."
                        isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    LoginView(isLoggedIn: .constant(false))
} 
