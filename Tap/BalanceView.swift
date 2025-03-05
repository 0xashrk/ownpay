import SwiftUI
import UIKit

struct BalanceView: View {
    @StateObject private var privyService = PrivyService.shared
    @State private var isRefreshing = false
    @State private var showingAccountSheet = false
    @State private var showCopiedToast = false
    @Binding var isMerchantMode: Bool
    
    // Monad Colors
    private let monadPurple = Color(hex: "836EF9")
    private let monadBlue = Color(hex: "200052")
    private let monadBerry = Color(hex: "A0055D")
    private let monadOffWhite = Color(hex: "FBFAF9")
    private let monadBlack = Color(hex: "0E100F")
    
    // Cyberpunk Colors
    private let cyberpunkCyan = Color(hex: "00FFFF")
    private let cyberpunkDark = Color(hex: "000000")
    private let cyberpunkGlow = Color(hex: "00FFFF").opacity(0.3)
    
    var body: some View {
        Group {
            if isMerchantMode {
                MerchantBalanceView(
                    privyService: privyService,
                    isRefreshing: $isRefreshing,
                    showingAccountSheet: $showingAccountSheet,
                    showCopiedToast: $showCopiedToast
                )
            } else {
                CustomerBalanceView(
                    privyService: privyService,
                    isRefreshing: $isRefreshing,
                    showingAccountSheet: $showingAccountSheet,
                    showCopiedToast: $showCopiedToast,
                    monadPurple: monadPurple,
                    monadBlue: monadBlue,
                    monadOffWhite: monadOffWhite,
                    monadBlack: monadBlack
                )
            }
        }
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
            AccountDetailsSheet(address: privyService.walletAddress ?? "", showCopiedToast: $showCopiedToast, isMerchant: isMerchantMode)
        }
        .overlay {
            if showCopiedToast {
                ToastView(message: "Address copied!", isMerchant: isMerchantMode)
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

struct MerchantBalanceView: View {
    @ObservedObject var privyService: PrivyService
    @Binding var isRefreshing: Bool
    @Binding var showingAccountSheet: Bool
    @Binding var showCopiedToast: Bool
    
    private let cyberpunkCyan = Color(hex: "00FFFF")
    private let cyberpunkDark = Color(hex: "000000")
    
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
                        .colorMultiply(cyberpunkCyan)
                    Spacer()
                    if privyService.walletAddress != nil {
                        Button {
                            showingAccountSheet = true
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(cyberpunkCyan.opacity(0.8))
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
                            Text("Available Balance")
                                .font(.subheadline)
                                .foregroundStyle(cyberpunkCyan.opacity(0.7))
                            Text(balance)
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundStyle(cyberpunkCyan)
                        } else {
                            Text("Fetching balance...")
                                .font(.body)
                                .foregroundStyle(cyberpunkCyan.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
                } else {
                    Text("Connecting wallet...")
                        .font(.body)
                        .foregroundStyle(cyberpunkCyan.opacity(0.7))
                }
                
                if isRefreshing {
                    ProgressView()
                        .tint(cyberpunkCyan)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(
                ZStack {
                    // Base gradient
                    LinearGradient(
                        colors: [
                            cyberpunkDark,
                            cyberpunkDark.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Subtle inner gradient
                    LinearGradient(
                        colors: [
                            cyberpunkCyan.opacity(0.05),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(cyberpunkCyan.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }
}

struct CustomerBalanceView: View {
    @ObservedObject var privyService: PrivyService
    @Binding var isRefreshing: Bool
    @Binding var showingAccountSheet: Bool
    @Binding var showCopiedToast: Bool
    let monadPurple: Color
    let monadBlue: Color
    let monadOffWhite: Color
    let monadBlack: Color
    
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
                    Spacer()
                    if privyService.walletAddress != nil {
                        Button {
                            showingAccountSheet = true
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(monadOffWhite.opacity(0.8))
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
            .frame(height: 200)
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
    }
}

struct AccountDetailsSheet: View {
    let address: String
    @Binding var showCopiedToast: Bool
    @Environment(\.dismiss) private var dismiss
    let isMerchant: Bool
    
    private let cyberpunkCyan = Color(hex: "00FFFF")
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Account Icon
                Circle()
                    .fill(isMerchant ? cyberpunkCyan.opacity(0.1) : Color(hex: "836EF9").opacity(0.1))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(isMerchant ? cyberpunkCyan : Color(hex: "836EF9"))
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
                        .background(isMerchant ? cyberpunkCyan.opacity(0.1) : Color(hex: "836EF9").opacity(0.1))
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
    let isMerchant: Bool
    
    private let cyberpunkCyan = Color(hex: "00FFFF")
    
    var body: some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isMerchant ? cyberpunkCyan : Color(hex: "836EF9"))
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
    BalanceView(isMerchantMode: .constant(false))
        .preferredColorScheme(.dark)
        .padding(.vertical)
} 
