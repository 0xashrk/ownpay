//
//  SuccessPaymentView.swift
//  Tap
//
//  Created by Ashwin Ravikumar on 06/03/2025.
//

import SwiftUI

struct PaymentSuccessView: View {
    var transactionDetails: [String: String]
    
    var body: some View {
        VStack(spacing: 16) {
            // Success header
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                
                Text("Payment Sent!")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 4)
            
            // Transaction details section
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                
                if let amount = transactionDetails["amount"] {
                    HStack {
                        Text("Amount:")
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(amount) MON")
                            .fontWeight(.semibold)
                    }
                }
                
                if let sender = transactionDetails["sender"] {
                    HStack {
                        Text("From:")
                            .fontWeight(.medium)
                        Spacer()
                        Text(sender)
                            .fontWeight(.regular)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                if let recipient = transactionDetails["recipient"] {
                    HStack {
                        Text("To:")
                            .fontWeight(.medium)
                        Spacer()
                        Text(recipient)
                            .fontWeight(.regular)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                if let note = transactionDetails["note"], !note.isEmpty {
                    HStack(alignment: .top) {
                        Text("Note:")
                            .fontWeight(.medium)
                        Spacer()
                        Text(note)
                            .fontWeight(.regular)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                if let hash = transactionDetails["hash"] {
                    Divider()
                    .padding(.vertical, 4)
                    
                    HStack {
                        Text("Tx Hash:")
                            .fontWeight(.medium)
                            .font(.subheadline)
                        Spacer()
                        Text(hash)
                            .fontWeight(.regular)
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .frame(maxWidth: 350)
    }
}

#Preview {
    SuccessPaymentView()
}
