import SwiftUI

struct WalletView: View {
    var body: some View {
        VStack(spacing: 30) {
            Text("Your Wallet")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            HStack(spacing: 20) {
                Button(action: {
                    // Send action
                }) {
                    VStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 40))
                        Text("Send")
                            .font(.headline)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(15)
                }
                
                Button(action: {
                    // Receive action
                }) {
                    VStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 40))
                        Text("Receive")
                            .font(.headline)
                    }
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(15)
                }
            }
        }
        .padding()
    }
}

#Preview {
    WalletView()
} 