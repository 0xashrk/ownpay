//
//  TapApp.swift
//  Tap
//
//  Created by Ashwin Ravikumar on 02/03/2025.
//

import SwiftUI
import SwiftData

@main
struct TapApp: App {
    @StateObject private var privyService = PrivyService.shared
    @State private var isLoggedIn = false
    
    // Create a ModelContainer for the PaymentTransaction model
    let modelContainer: ModelContainer
    
    init() {
        do {
            modelContainer = try ModelContainer(for: PaymentTransaction.self)
        } catch {
            fatalError("Failed to create ModelContainer for PaymentTransaction: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if !privyService.isReady {
                ProgressView("Initializing...")
            } else if isLoggedIn {
                WalletView(isLoggedIn: $isLoggedIn)
            } else {
                LoginView()
                    .onReceive(privyService.$authState) { state in
                        if case .authenticated = state {
                            isLoggedIn = true
                        } else if case .unauthenticated = state {
                            isLoggedIn = false
                        }
                    }
            }
        }
        .modelContainer(modelContainer)
    }
}
