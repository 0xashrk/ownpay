//
//  MerchantView.swift
//  Own Pay
//
//  Created by Ashwin Ravikumar on 11/03/2025.
//

import SwiftUI

struct MerchantView: View {
    @Binding var showingRequestForm: Bool
    @Binding var showingSendForm: Bool
    
    // New parameters with default values
    @Binding var isScanning: Bool
    let selectionGenerator: UISelectionFeedbackGenerator
    let bleService: BLEService?  // Made optional
    
    // Initialize with default values for backward compatibility
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
    
    var body: some View {
        VStack(spacing: 16) {
            // Only show discovery UI if bleService is provided
            if let bleService = bleService {
                HStack {
                    Text(isScanning ? "Discovering..." : "Ready to detect requests")
                        .foregroundColor(.secondary)
                    
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
                            Image(systemName: "wave.3.right")
                                .font(.system(size: 18))
                            Text("Discover")
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
            }
            
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
