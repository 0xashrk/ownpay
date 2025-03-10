import SwiftUI
import UIKit

struct BalanceView: View {
    @StateObject private var privyService = PrivyService.shared
    @State private var isRefreshing = false
    @State private var showingAccountSheet = false
    @State private var showCopiedToast = false
    @Binding var isMerchantMode: Bool
    
    // Cyberpunk Colors
    private let cyberCyan = Color(hex: "00FFFF")
    private let cyberDark = Color(hex: "000000")
    private let cyberWhite = Color(hex: "FFFFFF")
    
    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: isMerchantMode ? [
                cyberDark.opacity(0.95),
                cyberDark.opacity(0.8)
            ] : [
                cyberDark.opacity(0.8),
                cyberDark.opacity(0.95)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var accentColor: Color {
        isMerchantMode ? cyberCyan : cyberCyan
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Card
            VStack(spacing: 32) {
                // Top section with logo and account button
                HStack(spacing: 0) {
                    Image("monad-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 12)
                        .colorMultiply(cyberCyan) // Tint the logo cyan
                    Spacer()
                    if privyService.walletAddress != nil {
                        Button {
                            showingAccountSheet = true
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(cyberCyan.opacity(0.8))
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .padding(.trailing, -8)
                    }
                }
                
                if let address = privyService.walletAddress {
                    // Balance section
                    VStack(alignment: .leading, spacing: 12) {
                        if let balance = privyService.balance {
                            Text(isMerchantMode ? "Merchant Balance" : "Available Balance")
                                .font(.subheadline)
                                .foregroundStyle(cyberCyan.opacity(0.7))
                            Text(balance)
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundStyle(cyberCyan)
                                .shadow(color: cyberCyan.opacity(0.5), radius: 8, x: 0, y: 0)
                        } else {
                            Text("Fetching balance...")
                                .font(.body)
                                .foregroundStyle(cyberCyan.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
                } else {
                    Text("Connecting wallet...")
                        .font(.body)
                        .foregroundStyle(cyberCyan.opacity(0.7))
                }
                
                if isRefreshing {
                    ProgressView()
                        .tint(cyberCyan)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(
                ZStack {
                    // Base gradient
                    cardGradient
                    
                    // Cyberpunk overlay gradient
                    RadialGradient(
                        colors: [
                            cyberCyan.opacity(0.15),
                            .clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 400
                    )
                    
                    // Add subtle horizontal lines
                    VStack(spacing: 30) {
                        ForEach(0..<6) { _ in
                            Rectangle()
                                .fill(cyberCyan)
                                .frame(height: 1)
                                .opacity(0.1)
                        }
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .strokeBorder(cyberCyan.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: cyberCyan.opacity(0.3), radius: 15, x: 0, y: 10)
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

// Update AccountDetailsSheet with cyberpunk theme
struct AccountDetailsSheet: View {
    let address: String
    @Binding var showCopiedToast: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Circle()
                    .fill(Color(hex: "00FFFF").opacity(0.1))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color(hex: "00FFFF"))
                    )
                
                VStack(spacing: 8) {
                    Text("Account Address")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "00FFFF").opacity(0.7))
                    
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
                        .background(Color(hex: "00FFFF").opacity(0.1))
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
                    .foregroundStyle(Color(hex: "00FFFF"))
                }
            }
        }
    }
}

// Update ToastView with cyberpunk theme
struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: "00FFFF"))
            .clipShape(Capsule())
            .shadow(color: Color(hex: "00FFFF").opacity(0.5), radius: 10, x: 0, y: 5)
            .padding(.top, 8)
    }
}

// Keep the Color extension
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
    BalanceView(isMerchantMode: .constant(false))
        .preferredColorScheme(.dark)
        .padding(.vertical)
} 