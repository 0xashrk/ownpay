//
//  MerchantView.swift
//  Own Pay
//
//  Created by Ashwin Ravikumar on 11/03/2025.
//

import SwiftUI

struct MerchantView: View {
    @Binding var showingRequestForm: Bool
    @Binding var showingSendForm: Bool  // Add binding for the send form
    let selectionGenerator: UISelectionFeedbackGenerator
    
    var body: some View {
        VStack(spacing: 16) {
            // Request Payment button
            Button(action: {
                selectionGenerator.selectionChanged()
                showingRequestForm = true
            }) {
                HStack {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 24))
                    Text("Request Payment")
                        .font(.headline)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(15)
            }
            .padding(.horizontal)
            
            // Send MON button (added to match customer mode)
            Button(action: {
                selectionGenerator.selectionChanged()
                showingSendForm = true
            }) {
                HStack {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 24))
                    Text("Send MON")
                        .font(.headline)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(15)
            }
            .padding(.horizontal)
        }
    }
}
