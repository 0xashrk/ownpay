import SwiftUI

struct WalletView: View {
    @StateObject private var bleService = BLEService()
    @State private var messageText = ""
    @State private var showMessageInput = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Your Wallet")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            HStack(spacing: 20) {
                Button(action: {
                    showMessageInput = true
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
                    bleService.isAdvertising.toggle()
                    if bleService.isAdvertising {
                        bleService.startAdvertising()
                    } else {
                        bleService.stopAdvertising()
                    }
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
            
            if bleService.isAdvertising {
                Text("Waiting for connection...")
                    .foregroundColor(.green)
            }
            
            if !bleService.connectedDevices.isEmpty {
                VStack(alignment: .leading) {
                    Text("Connected Devices:")
                        .font(.headline)
                    ForEach(bleService.connectedDevices, id: \.self) { device in
                        Text(device)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
            }
        }
        .padding()
        .sheet(isPresented: $showMessageInput) {
            MessageInputView(bleService: bleService, messageText: $messageText)
        }
    }
}

struct MessageInputView: View {
    @ObservedObject var bleService: BLEService
    @Binding var messageText: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Enter message", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button(action: {
                    bleService.sendMessage(messageText)
                    messageText = ""
                    dismiss()
                }) {
                    Text("Send Message")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(messageText.isEmpty)
                
                Spacer()
            }
            .navigationTitle("Send Message")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
        }
    }
}

#Preview {
    WalletView()
} 