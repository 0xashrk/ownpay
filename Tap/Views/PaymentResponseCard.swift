import SwiftUI

struct PaymentResponseCard: View {
    @StateObject private var viewModel: PaymentResponseViewModel
    
    init(message: String) {
        _viewModel = StateObject(wrappedValue: PaymentResponseViewModel(message: message))
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Payment Response")
                .font(.headline)
            
            Image(systemName: viewModel.iconName)
                .font(.system(size: 40))
                .foregroundColor(viewModel.statusColor)
            
            Text(viewModel.statusText)
                .font(.title3)
                .foregroundColor(viewModel.statusColor)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct PaymentResponseCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            PaymentResponseCard(message: "PAYMENT_RESPONSE:APPROVED")
            PaymentResponseCard(message: "PAYMENT_RESPONSE:DECLINED")
        }
        .padding()
    }
} 