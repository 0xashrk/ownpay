//
//  TapApp.swift
//  Tap
//
//  Created by Ashwin Ravikumar on 02/03/2025.
//

import SwiftUI

@main
struct TapApp: App {
    @StateObject private var privyService = PrivyService.shared
    @State private var isLoggedIn = false
    
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
    }
}
