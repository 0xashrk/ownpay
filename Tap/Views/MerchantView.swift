//
//  MerchantView.swift
//  Own Pay
//
//  Created by Ashwin Ravikumar on 11/03/2025.
//

import SwiftUI
import Combine

// Add this at the top of the file, after the imports
extension Notification.Name {
    static let dismissFriendPicker = Notification.Name("dismissFriendPicker")
}

struct MerchantView: View {
    @Binding var showingRequestForm: Bool
    @Binding var showingSendForm: Bool
    @Binding var isScanning: Bool
    
    let selectionGenerator: UISelectionFeedbackGenerator
    let bleService: BLEService?
    @ObservedObject var viewModel: MerchantViewModel
    
    @Environment(\.colorScheme) var colorScheme
    
    @State private var showingRequestFormForFriend = false
    
    // Initialize with existing parameters to avoid breaking changes
    init(showingRequestForm: Binding<Bool>, 
         showingSendForm: Binding<Bool>,
         selectionGenerator: UISelectionFeedbackGenerator,
         isScanning: Binding<Bool> = .constant(false),
         bleService: BLEService? = nil,
         viewModel: MerchantViewModel) {
        self._showingRequestForm = showingRequestForm
        self._showingSendForm = showingSendForm
        self._isScanning = isScanning
        self.selectionGenerator = selectionGenerator
        self.bleService = bleService
        self._viewModel = ObservedObject(wrappedValue: viewModel)
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
                
                // Recent requests using new view
                RecentRequestsView(viewModel: viewModel)
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $viewModel.showingFriendPicker) {
            NavigationStack(path: $viewModel.navigationPath) {
                FriendPickerView(
                    selectedFriend: $viewModel.selectedFriend,
                    isPresented: $viewModel.showingFriendPicker,
                    mode: .request,
                    onSelect: { friend in
                        let destination = RequestPaymentFormView(
                            amount: .constant(""),
                            selectedFriend: friend,
                            onRequest: { amount, note in
                                // Call the API to create payment request
                                Task {
                                    do {
                                        // Convert Double to Decimal
                                        let decimalAmount = Decimal(amount)
                                        _ = try await APIService.shared.createPaymentRequest(
                                            friendId: friend.id,
                                            amount: decimalAmount,  // Now passing Decimal
                                            note: note
                                        )
                                        await MainActor.run {
                                            viewModel.showingFriendPicker = false
                                        }
                                    } catch {
                                        print("Error creating payment request: \(error)")
                                    }
                                }
                            }
                        )
                        viewModel.navigationPath.append(destination)
                    }
                )
                .navigationDestination(for: RequestPaymentFormView.self) { view in
                    view
                        .navigationTitle("Request Payment")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dismissFriendPicker)) { _ in
                viewModel.showingFriendPicker = false
            }
        }
        .sheet(isPresented: $showingRequestForm) {
            NavigationStack {
                RequestPaymentFormView(
                    amount: .constant(""),
                    onRequest: { amount, note in
                        showingRequestForm = false
                    }
                )
                .navigationTitle("Request Payment")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onAppear {
            viewModel.loadRecentRequests()
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
        bleService: BLEService(),
        viewModel: MerchantViewModel()
    )
    .padding()
}
