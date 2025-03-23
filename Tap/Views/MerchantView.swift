//
//  MerchantView.swift
//  Own Pay
//
//  Created by Ashwin Ravikumar on 11/03/2025.
//

import SwiftUI
import Combine

struct MerchantView: View {
    @Binding var showingRequestForm: Bool
    @Binding var showingSendForm: Bool
    @Binding var isScanning: Bool
    
    let selectionGenerator: UISelectionFeedbackGenerator
    let bleService: BLEService?
    
    // View Model for better separation of concerns
    @StateObject private var viewModel = MerchantViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    // Initialize with existing parameters to avoid breaking changes
    init(showingRequestForm: Binding<Bool>, 
         showingSendForm: Binding<Bool>,
         selectionGenerator: UISelectionFeedbackGenerator,
         isScanning: Binding<Bool> = .constant(false),
         bleService: BLEService? = nil) {
        self._showingRequestForm = showingRequestForm
        self._showingSendForm = showingSendForm
        self._isScanning = isScanning
        self.selectionGenerator = selectionGenerator
        self.bleService = bleService
    }
    
    // Theme properties
    private var primaryColor: Color { Color.blue }
    private var secondaryColor: Color { Color.purple }
    private var surfaceColor: Color { colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1) }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // BLE Discovery section
                if let bleService = bleService {
                    discoverySection(bleService: bleService)
                }
                
                // Main action cards
                actionCardsSection
                
                // Recent requests
                recentRequestsSection
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $viewModel.showingFriendPicker) {
            NavigationView {
                FriendPickerView(
                    selectedFriend: $viewModel.selectedFriend,
                    isPresented: $viewModel.showingFriendPicker,
                    onSendRequest: { friend in
                        viewModel.selectedFriend = friend
                        viewModel.showingFriendPicker = false
                        showingRequestForm = true
                    }
                )
            }
            .presentationDetents([.medium, .large])
        }
        .onChange(of: viewModel.selectedFriend) { newValue in
            // Could trigger additional actions when friend is selected
        }
        .onAppear {
            viewModel.loadFriends()
        }
    }
    
    // MARK: - UI Components
    
    private func discoverySection(bleService: BLEService) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(isScanning ? "Discovering..." : "Ready to detect requests")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if isScanning {
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: 100)
                }
            }
            
            Spacer()
            
            Button(action: {
                selectionGenerator.selectionChanged()
                withAnimation {
                    isScanning = true
                }
                bleService.stopScanning()
                bleService.startScanning()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        isScanning = false
                    }
                }
            }) {
                Label("Discover", systemImage: "wave.3.right")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(primaryColor.opacity(0.1))
                    .foregroundColor(primaryColor)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(surfaceColor)
        .cornerRadius(12)
    }
    
    private var actionCardsSection: some View {
        VStack(spacing: 16) {
            Text("Request or Send")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                // Nearby Request Card
                actionCard(
                    title: "Request Nearby",
                    subtitle: "Use contactless",
                    icon: "arrow.down.circle.fill",
                    color: primaryColor,
                    action: {
                        selectionGenerator.selectionChanged()
                        showingRequestForm = true
                    }
                )
                
                // Request from Friend Card
                actionCard(
                    title: "Request from Friend",
                    subtitle: "Select a user",
                    icon: "person.fill.badge.plus",
                    color: secondaryColor,
                    action: {
                        selectionGenerator.selectionChanged()
                        viewModel.showingFriendPicker = true
                    }
                )
            }
            
            // Send Money Card
            Button(action: {
                selectionGenerator.selectionChanged()
                showingSendForm = true
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Send MON")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Transfer to any wallet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "paperplane.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(primaryColor)
                }
                .padding()
                .background(surfaceColor)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private func actionCard(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                
                Spacer()
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .padding()
            .background(surfaceColor)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var recentRequestsSection: some View {
        VStack(spacing: 12) {
            // Header with expand/collapse button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.isRecentRequestsExpanded.toggle()
                }
            }) {
                HStack {
                    Text("Recent Requests")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Image(systemName: viewModel.isRecentRequestsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if viewModel.isRecentRequestsExpanded {
                        Button(action: {
                            // Show all requests
                        }) {
                            Text("View All")
                                .font(.subheadline)
                                .foregroundColor(primaryColor)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Content (only visible when expanded)
            if viewModel.isRecentRequestsExpanded {
                if viewModel.recentRequests.isEmpty {
                    emptyRequestsView
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    ForEach(viewModel.recentRequests) { request in
                        requestRow(request: request)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .padding(.top)
    }
    
    private var emptyRequestsView: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
                .padding()
            
            Text("No recent requests")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Your recent payment requests will appear here")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(surfaceColor)
        .cornerRadius(12)
    }
    
    private func requestRow(request: PaymentRequest) -> some View {
        HStack(spacing: 12) {
            // Avatar/Icon
            Image(systemName: request.type == .user ? "person.crop.circle.fill" : "wave.3.right.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(request.type == .user ? secondaryColor : primaryColor)
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(request.title)
                    .font(.headline)
                
                Text(request.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(request.timeAgo)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Amount
            Text(request.amount)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding()
        .background(surfaceColor)
        .cornerRadius(12)
    }
}

// MARK: - Supporting Views

struct FriendPickerView: View {
    @Binding var selectedFriend: Friend?
    @Binding var isPresented: Bool
    @State private var searchText = ""
    let onSendRequest: (Friend) -> Void
    
    @StateObject private var viewModel = FriendsViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    private var surfaceColor: Color { colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1) }
    
    var filteredFriends: [Friend] {
        if searchText.isEmpty {
            return viewModel.friends
        } else {
            return viewModel.friends.filter {
                $0.name.lowercased().contains(searchText.lowercased()) ||
                $0.username.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search friends", text: $searchText)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(surfaceColor)
            .cornerRadius(10)
            .padding()
            
            if viewModel.isLoading {
                ProgressView("Loading friends...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.red.opacity(0.5))
                        .padding()
                    
                    Text("Error loading friends")
                        .font(.headline)
                    
                    if let apiError = error as? APIError {
                        Text(apiError.localizedDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        Text("Unable to load friends. Please try again.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button(action: {
                        viewModel.loadFriends()
                    }) {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding()
            } else if filteredFriends.isEmpty {
                emptyFriendsView
            } else {
                // Friends list
                List {
                    ForEach(filteredFriends) { friend in
                        friendRow(friend: friend)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Select Friend")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    isPresented = false
                }
            }
        }
        .onAppear {
            viewModel.loadFriends()
        }
    }
    
    private var emptyFriendsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.5))
                .padding()
            
            if searchText.isEmpty {
                Text("No friends yet")
                    .font(.headline)
                
                Text("You haven't added any friends to request from")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    // Action to add friends
                }) {
                    Label("Add Friends", systemImage: "person.badge.plus")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            } else {
                Text("No matches found")
                    .font(.headline)
                
                Text("Try a different search term")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func friendRow(friend: Friend) -> some View {
        Button(action: {
            selectedFriend = friend
            onSendRequest(friend)
        }) {
            HStack(spacing: 16) {
                // Avatar image
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: friend.avatarName)
                        .font(.system(size: 24))
                        .foregroundColor(.purple)
                }
                
                // Friend info
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.name)
                        .font(.headline)
                    
                    Text(friend.username)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Direct request button
                Button(action: {
                    selectedFriend = friend
                    onSendRequest(friend)
                }) {
                    Text("Request")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - View Models

class MerchantViewModel: ObservableObject {
    @Published var selectedFriend: Friend?
    @Published var showingFriendPicker = false
    @Published var recentRequests: [PaymentRequest] = []
    @Published var isRecentRequestsExpanded: Bool = true
    
    func loadFriends() {
        // In a real app, this would load friends from your backend
    }
    
    func loadRecentRequests() {
        // This would fetch recent payment requests from your backend
        // For now, let's add some sample data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.recentRequests = [
                PaymentRequest(
                    id: "1",
                    title: "Alex Chen",
                    description: "Lunch payment",
                    amount: "5.00 MON",
                    timeAgo: "2h ago",
                    type: .user
                ),
                PaymentRequest(
                    id: "2",
                    title: "Nearby Request",
                    description: "Coffee shop",
                    amount: "3.50 MON",
                    timeAgo: "Yesterday",
                    type: .nearby
                )
            ]
        }
    }
}

class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    func loadFriends() {
        isLoading = true
        error = nil
        
        print("🔄 Starting to load friends...")
        
        Task {
            do {
                print("📡 Making API request to fetch user profiles...")
                let profiles = try await APIService.shared.getUserProfiles()
                print("📥 Received \(profiles.count) profiles from API")
                
                await MainActor.run {
                    self.friends = profiles.map { profile in
                        Friend(
                            id: profile.id,
                            name: profile.username,
                            username: "@\(profile.username)",
                            avatarName: "person.crop.circle.fill"
                        )
                    }
                    self.isLoading = false
                }
            } catch {
                print("❌ Error in loadFriends: \(error)")
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Models

struct Friend: Identifiable, Equatable {
    var id: String
    var name: String
    var username: String
    var avatarName: String
}

struct PaymentRequest: Identifiable {
    var id: String
    var title: String
    var description: String
    var amount: String
    var timeAgo: String
    var type: RequestType
    
    enum RequestType {
        case nearby
        case user
    }
}

#Preview {
    MerchantView(
        showingRequestForm: .constant(false),
        showingSendForm: .constant(false),
        selectionGenerator: UISelectionFeedbackGenerator(),
        isScanning: .constant(false),
        bleService: BLEService()
    )
    .padding()
}
