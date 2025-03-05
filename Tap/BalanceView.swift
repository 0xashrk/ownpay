import SwiftUI
import UIKit

struct BalanceView: View {
    @StateObject private var privyService = PrivyService.shared
    @State private var isRefreshing = false
    @State private var showingAccountSheet = false
    @State private var showCopiedToast = false
    
    // Monad Colors
    private let monadPurple = Color(hex: "836EF9")
    private let monadBlue = Color(hex: "200052")
    private let monadBerry = Color(hex: "A0055D")
    private let monadOffWhite = Color(hex: "FBFAF9")
    private let monadBlack = Color(hex: "0E100F")
    
    var body: some View {
        VStack(spacing: 0) {
            // Card
            VStack(spacing: 32) {
                // Top section with logo and account button
                HStack {
                    Image("monad-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 12)
                    Spacer()
                    if privyService.walletAddress != nil {
                        Button {
                            showingAccountSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "ellipsis.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .font(.system(size: 22))
                                    .foregroundStyle(monadOffWhite.opacity(0.8))
                            }
                            .padding(8)
                            .background(monadOffWhite.opacity(0.1))
                            .clipShape(Circle())
                        }
                    }
                }
                
                if let address = privyService.walletAddress {
                    // Balance section
                    VStack(alignment: .leading, spacing: 12) {
                        if let balance = privyService.balance {
                            Text("Available Balance")
                                .font(.subheadline)
                                .foregroundStyle(monadOffWhite.opacity(0.7))
                            Text(balance)
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundStyle(monadPurple)
                                .shadow(color: monadPurple.opacity(0.5), radius: 8, x: 0, y: 0)
                        } else {
                            Text("Fetching balance...")
                                .font(.body)
                                .foregroundStyle(monadOffWhite.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
                } else {
                    Text("Connecting wallet...")
                        .font(.body)
                        .foregroundStyle(monadOffWhite.opacity(0.7))
                }
                
                if isRefreshing {
                    ProgressView()
                        .tint(monadPurple)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .frame(height: 200) // Fixed height for card
            .background(
                ZStack {
                    // Base gradient
                    LinearGradient(
                        colors: [
                            monadBlue,
                            monadBlue.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Subtle overlay gradient
                    RadialGradient(
                        colors: [
                            monadPurple.opacity(0.15),
                            .clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 400
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(monadPurple.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: monadBlack.opacity(0.3), radius: 15, x: 0, y: 10)
        }
        .padding(.horizontal)
        .refreshable {
            await refreshBalance()
        }
        .task {
            if privyService.walletAddress != nil {
                if case .notConnected = privyService.embeddedWalletState {
                    await privyService.connectWallet()
                }
                await privyService.fetchBalance()
            }
        }
        .sheet(isPresented: $showingAccountSheet) {
            AccountDetailsSheet(address: privyService.walletAddress ?? "", showCopiedToast: $showCopiedToast)
        }
        .overlay {
            if showCopiedToast {
                ToastView(message: "Address copied!")
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showCopiedToast = false
                            }
                        }
                    }
            }
        }
    }
    
    private func refreshBalance() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        
        if case .notConnected = privyService.embeddedWalletState {
            await privyService.connectWallet()
        }
        
        await privyService.fetchBalance()
    }
}

struct AccountDetailsSheet: View {
    let address: String
    @Binding var showCopiedToast: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Account Icon
                Circle()
                    .fill(Color(hex: "836EF9").opacity(0.1))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color(hex: "836EF9"))
                    )
                
                // Account Details
                VStack(spacing: 8) {
                    Text("Account Address")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        UIPasteboard.general.string = address
                        withAnimation {
                            showCopiedToast = true
                        }
                        dismiss()
                    } label: {
                        HStack {
                            Text(address)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(hex: "836EF9").opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Account Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: "836EF9"))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
            .padding(.top, 8)
    }
}

// Helper extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    BalanceView()
        .preferredColorScheme(.dark)
        .padding(.vertical)
} 
