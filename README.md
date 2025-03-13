## Overview
Own Pay is a mobile cryptocurrency payment application that enables fast, secure, and user-friendly transactions on the Monad blockchain. The app facilitates proximity-based payments using Bluetooth technology, allowing users to make payments to nearby devices without the need for QR code scanning or address sharing for each transaction.

## Features

### Core Payment Functionality
- **Proximity-Based Payments**: Discover nearby payment requests using Bluetooth Low Energy (BLE)
- **QR Code Scanning**: Easily scan wallet addresses via QR codes
- **Multiple Payment Modes**:
  - **Customer Mode**: Send payments to merchants
  - **Merchant Mode**: Request payments from customers
  - **Faucet Mode**: Distribute small amounts of MON to users

### User Experience
- **Apple Pay-Inspired UX**: Smooth, intuitive payment flows with familiar animations
- **Real-Time Payment Status**: Clear visual feedback on payment progress and confirmation
- **Transaction History**: Comprehensive record of past payments
- **Wallet Management**: View balance and transaction history

### Security & Protection
- **Embedded Wallet**: Secure cryptocurrency wallet powered by Privy
- **Sybil Resistance**: Protection against excessive faucet usage with cooldown periods
- **Transaction Verification**: Proper feedback and confirmation for all payments

## Technical Architecture

### Frontend
- Built with SwiftUI for iOS
- Responsive and animated UI components
- Follows Apple's design guidelines for a native feel

### Backend & Blockchain
- Integrates with Monad blockchain testnet
- Uses Privy SDK for wallet creation and management
- Performs transactions via JSON-RPC calls to the Monad network

### Data Storage
- Uses SwiftData for local transaction history
- Persistent storage for user preferences and settings

### Communication
- Bluetooth Low Energy (BLE) for device-to-device communication
- Structured message format for payment requests and responses

## Getting Started

### Prerequisites
- iOS device with Bluetooth capability
- Xcode 15 or newer
- A Monad testnet wallet (or use the faucet feature to get started)

### Installation
1. Clone the repository
2. Open the project in Xcode
3. Build and run on your iOS device

## Usage Scenarios

### For Customers
1. Open the app and switch to Customer mode
2. Discover nearby payment requests from merchants
3. Review and approve payment requests
4. Receive confirmation when payments complete

### For Merchants
1. Switch to Merchant mode
2. Request specific payment amount
3. Wait for customer to discover and approve payment
4. Receive payment confirmation

### For Faucet Operators
1. Switch to Faucet mode
2. Scan a user's wallet QR code
3. Send a small amount of MON to help them get started

## Privacy & Permissions
Own Pay requires the following permissions:
- Bluetooth: For discovering nearby payment requests and sending responses
- Camera: For scanning QR codes of wallet addresses

## License
[Insert appropriate license information]

## Acknowledgements
- Monad Blockchain team
- Privy SDK for wallet infrastructure
- All contributors to the project
