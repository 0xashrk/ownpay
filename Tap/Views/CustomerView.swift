//
//  CustomerView.swift
//  Own Pay
//
//  Created by Ashwin Ravikumar on 11/03/2025.
//

import SwiftUI

struct CustomerView: View {
    @Binding var isScanning: Bool
    @Binding var showingSendForm: Bool
    let selectionGenerator: UISelectionFeedbackGenerator
    let bleService: BLEService
    
    var body: some View {
        // Customer View - shows status and send button
        VStack(spacing: 16) {
            HStack {
                Text(isScanning ? "Scanning..." : "Scanning for payment requests...")
                    .foregroundColor(.secondary)
                
                // Added scan button
                Button(action: {
                    selectionGenerator.selectionChanged()
                    withAnimation {
                        isScanning = true
                    }
                    // Restart scanning
                    bleService.stopScanning()
                    bleService.startScanning()
                    
                    // Reset scanning indicator after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            isScanning = false
                        }
                    }
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 18))
                        Text("Scan")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
            }
            .padding(.top)
            .padding(.horizontal)
            
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
