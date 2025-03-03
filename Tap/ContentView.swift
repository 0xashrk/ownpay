//
//  ContentView.swift
//  Tap
//
//  Created by Ashwin Ravikumar on 02/03/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn = true // Since we're already logged in when we reach this view
    
    var body: some View {
        WalletView(isLoggedIn: $isLoggedIn)
    }
}

#Preview {
    ContentView()
}
