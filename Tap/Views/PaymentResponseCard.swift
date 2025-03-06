import SwiftUI

struct PaymentResponseCard: View {
    @StateObject private var viewModel: PaymentResponseViewModel
    
    init(message: String) {
        _viewModel = StateObject(wrappedValue: PaymentResponseViewModel(message: message))
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 12) {
                Text("Payment Response")
                    .font(.headline)
                
                Image(systemName: viewModel.iconName)
                    .font(.system(size: 40))
                    .foregroundColor(viewModel.statusColor)
                
                Text(viewModel.statusText)
                    .font(.title3)
                    .foregroundColor(viewModel.statusColor)
                
                // Transaction details section
                if viewModel.hasTransactionDetails {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()
                            .padding(.vertical, 8)
                        
                        if let amount = viewModel.amount {
                            HStack {
                                Text("Amount:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(amount) MON")
                                    .fontWeight(.semibold)
                            }
                        }
                        
                        if let sender = viewModel.sender {
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
                        
                        if let recipient = viewModel.recipient {
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
                        
                        if let note = viewModel.note, !note.isEmpty {
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
                        
                        if let hash = viewModel.transactionHash {
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
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
            .frame(width: geometry.size.width, height: nil)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            // This ensures proper vertical centering
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}

struct PaymentResponseCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            // Add a background in the preview to better show the translucency
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            PaymentResponseCard(message: "PAYMENT_RESPONSE:APPROVED:0x123f6789abcdef0123456789abcdef0123456789:10:0x1234wallet5678:0xmerchant1234address:Coffee")
            .padding(.horizontal)
        }
    }
} 