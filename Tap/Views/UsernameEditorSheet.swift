import SwiftUI
import Combine

struct UsernameEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = UsernameEditorViewModel()
    var onSuccess: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Title and explanation
                Text("Choose a username")
                    .font(.headline)
                    .padding(.top)
                
                Text("This will be your public identity in the app.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Username field with availability indicator
                HStack {
                    TextField("Username", text: $viewModel.username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(viewModel.usernameFieldBorderColor, lineWidth: 2)
                        )
                        .disabled(viewModel.isUpdating)
                    
                    // Availability indicator
                    Group {
                        if viewModel.isCheckingAvailability {
                            ProgressView()
                        } else if !viewModel.username.isEmpty {
                            if viewModel.isAvailable == true {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else if viewModel.isAvailable == false {
                                Image(systemName: "x.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .frame(width: 24)
                }
                .padding(.horizontal)
                
                // Validation message
                if let validationMessage = viewModel.validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundColor(viewModel.validationMessageColor)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Save Button
                Button(action: {
                    Task {
                        if await viewModel.updateUsername() {
                            onSuccess(viewModel.username)
                            dismiss()
                        }
                    }
                }) {
                    if viewModel.isUpdating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.canSubmit ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(!viewModel.canSubmit || viewModel.isUpdating)
            }
            .padding(.bottom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isUpdating)
                }
            }
            .alert("Error Updating Username", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
}

class UsernameEditorViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var isAvailable: Bool?
    @Published var isCheckingAvailability: Bool = false
    @Published var validationMessage: String?
    @Published var isUpdating: Bool = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private var debounceTimer: Timer?
    
    init() {
        // Set initial username from user profile
        if let currentUsername = UserProfileService.shared.username {
            username = currentUsername
        }
        
        // Set up debounced username checking
        $username
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] username in
                self?.checkUsernameValidity(username)
            }
            .store(in: &cancellables)
    }
    
    var canSubmit: Bool {
        return isAvailable == true && !username.isEmpty && !isCheckingAvailability && !isUpdating
    }
    
    var usernameFieldBorderColor: Color {
        if username.isEmpty {
            return Color.clear  // No border for empty field
        } else if isCheckingAvailability {
            return Color.yellow // Checking
        } else if isAvailable == true {
            return Color.green  // Available
        } else {
            return Color.red    // Taken or invalid
        }
    }
    
    var validationMessageColor: Color {
        return isAvailable == true ? .green : .red
    }
    
    private func checkUsernameValidity(_ username: String) {
        // Reset states
        validationMessage = nil
        
        // Basic validation
        if username.isEmpty {
            isAvailable = nil
            return
        }
        
        if username.count < 3 {
            validationMessage = "Username must be at least 3 characters"
            isAvailable = false
            return
        }
        
        if username.count > 20 {
            validationMessage = "Username must be less than 20 characters"
            isAvailable = false
            return
        }
        
        // Only allow alphanumeric and underscores
        let regex = "^[a-zA-Z0-9_]+$"
        if !NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: username) {
            validationMessage = "Username can only contain letters, numbers, and underscores"
            isAvailable = false
            return
        }
        
        // Check if username has changed from current
        if username == UserProfileService.shared.username {
            validationMessage = "This is your current username"
            isAvailable = true
            return
        }
        
        // If we passed all basic validation, check availability
        checkAvailability(username)
    }
    
    private func checkAvailability(_ username: String) {
        isCheckingAvailability = true
        
        Task {
            do {
                let response = try await APIService.shared.checkUsernameAvailability(username: username)
                
                await MainActor.run {
                    self.isCheckingAvailability = false
                    self.isAvailable = !response.taken
                    self.validationMessage = response.taken ? 
                        "Username is already taken" : 
                        "Username is available"
                }
            } catch {
                await MainActor.run {
                    self.isCheckingAvailability = false
                    self.isAvailable = false
                    self.validationMessage = "Error checking availability"
                }
            }
        }
    }
    
    func updateUsername() async -> Bool {
        guard canSubmit else { return false }
        
        await MainActor.run {
            isUpdating = true
        }
        
        do {
            let response = try await APIService.shared.updateProfile(username: username)
            
            await MainActor.run {
                isUpdating = false
                if !response.success {
                    self.errorMessage = "Failed to update username"
                } else {
                    // Update local profile
                    UserProfileService.shared.updateUsername(response.username)
                }
            }
            
            return response.success
        } catch let error as DecodingError {
            await MainActor.run {
                isUpdating = false
                // More user-friendly error message
                errorMessage = "The username was updated, but there was an issue displaying the result. Please check your profile."
                print("Profile update parsing error: \(error)")
            }
            
            // Return true since the update likely succeeded
            return true
        } catch {
            await MainActor.run {
                isUpdating = false
                errorMessage = "Error: \(error.localizedDescription)"
                print("Profile update error: \(error)")
            }
            
            return false
        }
    }
} 