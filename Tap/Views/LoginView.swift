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
    @Environment(\.colorScheme) var colorScheme
    
    // Theme colors
    private var accentColor: Color { Color.blue }
    private var errorColor: Color { Color.red }
    private var backgroundColor: Color { colorScheme == .dark ? Color.black.opacity(0.6) : Color.white }
    private var secondaryBgColor: Color { colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1) }
    
    var body: some View {
        Group {
            if !privyService.isReady {
                ZStack {
                    backgroundColor.ignoresSafeArea()
                    VStack {
                        ProgressView("Initializing...")
                            .padding()
                            .background(secondaryBgColor)
                            .cornerRadius(10)
                    }
                }
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
                GeometryReader { geometry in
                    ZStack {
                        backgroundColor.ignoresSafeArea()
                        
                        ScrollView(showsIndicators: false) {
                            // This spacer helps center the content
                            Spacer(minLength: max(0, (geometry.size.height - 600) / 2))
                                .frame(height: max(0, (geometry.size.height - 600) / 2))
                            
                            VStack(spacing: 32) {
                                // Logo/Brand section
                                VStack(spacing: 16) {
                                    Image(systemName: "creditcard.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(accentColor)
                                    
                                    Text("Welcome to Own Pay")
                                        .font(.system(size: 28, weight: .bold))
                                        .multilineTextAlignment(.center)
                                    
                                    Text("Contactless MON payments")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                
                                if !showingOTPInput {
                                    // Login Card
                                    VStack(spacing: 24) {
                                        // Email Input
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Email")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            
                                            HStack {
                                                Image(systemName: "envelope")
                                                    .foregroundColor(.secondary)
                                                
                                                TextField("Enter your email", text: $email)
                                                    .textCase(.lowercase)
                                                    .keyboardType(.emailAddress)
                                                    .autocapitalization(.none)
                                                    .disabled(isLoading)
                                                    .padding(12)
                                                    .background(secondaryBgColor)
                                                    .cornerRadius(8)
                                            }
                                        }
                                        
                                        // Continue Button
                                        Button(action: sendOTP) {
                                            if isLoading {
                                                HStack {
                                                    Spacer()
                                                    ProgressView()
                                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    Spacer()
                                                }
                                                .padding()
                                            } else {
                                                HStack {
                                                    Spacer()
                                                    Text("Continue with Email")
                                                        .fontWeight(.semibold)
                                                    Spacer()
                                                }
                                                .padding()
                                            }
                                        }
                                        .background(email.isEmpty ? accentColor.opacity(0.3) : accentColor)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                        .disabled(isLoading || email.isEmpty)
                                    }
                                    .padding(.horizontal, 20)
                                } else {
                                    // OTP Verification Card
                                    VStack(spacing: 24) {
                                        // Header
                                        VStack(spacing: 8) {
                                            Text("Verification Code")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            
                                            Text("We sent a code to \(email)")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.center)
                                        }
                                        
                                        // OTP Input
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Enter Code")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            
                                            HStack {
                                                Image(systemName: "lock.shield")
                                                    .foregroundColor(.secondary)
                                                
                                                TextField("6-digit code", text: $otpCode)
                                                    .keyboardType(.numberPad)
                                                    .disabled(isLoading)
                                                    .padding(12)
                                                    .background(secondaryBgColor)
                                                    .cornerRadius(8)
                                            }
                                        }
                                        
                                        // Verify Button
                                        Button(action: verifyOTP) {
                                            if isLoading {
                                                HStack {
                                                    Spacer()
                                                    ProgressView()
                                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    Spacer()
                                                }
                                                .padding()
                                            } else {
                                                HStack {
                                                    Spacer()
                                                    Text("Verify")
                                                        .fontWeight(.semibold)
                                                    Spacer()
                                                }
                                                .padding()
                                            }
                                        }
                                        .background(otpCode.count != 6 ? accentColor.opacity(0.3) : accentColor)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                        .disabled(isLoading || otpCode.count != 6)
                                        
                                        // Resend Button
                                        Button(action: sendOTP) {
                                            Text("Resend Code")
                                                .foregroundColor(accentColor)
                                        }
                                        .disabled(isLoading)
                                        .padding(.top, 8)
                                    }
                                    .padding(.horizontal, 20)
                                }
                                
                                // Error Message
                                if let error = errorMessage {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundColor(errorColor)
                                        Text(error)
                                            .font(.caption)
                                            .foregroundColor(errorColor)
                                            .multilineTextAlignment(.center)
                                    }
                                    .padding()
                                    .background(errorColor.opacity(0.1))
                                    .cornerRadius(8)
                                    .padding(.horizontal, 20)
                                }
                                
                                // This spacer helps center the content from the bottom
                                Spacer(minLength: max(0, (geometry.size.height - 600) / 2))
                                    .frame(height: max(0, (geometry.size.height - 600) / 2))
                            }
                            .frame(minHeight: geometry.size.height)
                            .padding(.top, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
        }
        .onReceive(privyService.$authState) { state in
            if case .authenticated = state {
                isLoggedIn = true
                
                // Create wallet if needed after successful login
                Task {
                    await privyService.createEthereumWalletIfNeeded()
                }
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
