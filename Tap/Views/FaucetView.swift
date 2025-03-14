//
//  FaucetView.swift
//  Own Pay
//
//  Created by Ashwin Ravikumar on 11/03/2025.
//

import SwiftUI
import AVFoundation
import SwiftData

struct FaucetView: View {
    @Binding var isScanning: Bool
    @Binding var showingSendForm: Bool
    let selectionGenerator: UISelectionFeedbackGenerator
    let bleService: BLEService
    @State private var showingQRScanner = false
    @StateObject private var privyService = PrivyService.shared
    @StateObject private var paymentViewModel = PaymentViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var scannedAddress: String? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(isScanning ? "Discovering..." : "Ready to detect requests")
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
            
            // Updated wallet address scan button
            Button(action: {
                selectionGenerator.selectionChanged()
                showingQRScanner = true
            }) {
                HStack {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 24))
                    Text("Scan Wallet Address")
                        .font(.headline)
                }
                .foregroundColor(.purple)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(15)
            }
            .padding(.horizontal)
            
            // Display PaymentRequestCard for scanned address if available
            if let address = scannedAddress {
                // Create a simulated payment request in the format that PaymentRequestCard expects
                let requestMessage = "PAYMENT_REQUEST:0.05:\(address):Faucet Payment:QRScan"
                
                PaymentRequestCard(
                    message: requestMessage,
                    bleService: bleService,
                    settingsViewModel: SettingsViewModel.shared,
                    onPaymentAction: { approved in
                        _ = paymentViewModel.processPaymentRequest(
                            message: requestMessage,
                            approved: approved,
                            modelContext: modelContext,
                            privyService: privyService,
                            bleService: bleService,
                            settingsViewModel: SettingsViewModel.shared,
                            playSound: { }
                        )
                        
                        // Clear the scanned address to remove the card after processing
                        if approved {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                scannedAddress = nil
                            }
                        } else {
                            scannedAddress = nil
                        }
                    }
                )
                .padding(.horizontal)
            }
        }
        .overlay {
            if paymentViewModel.showingPaymentSuccess {
                PaymentSuccessView(transactionDetails: paymentViewModel.currentTransactionDetails)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showingQRScanner) {
            QRScannerView { result in
                print("Scanned wallet address: \(result)")
                showingQRScanner = false
                
                // Set the scanned address to trigger the PaymentRequestCard
                scannedAddress = result
            }
        }
        .alert(
            "Faucet Alert",
            isPresented: $paymentViewModel.showingFaucetAlert,
            actions: {
                Button("OK") {
                    paymentViewModel.showingFaucetAlert = false
                }
            },
            message: {
                Text(paymentViewModel.faucetAlertMessage)
            }
        )
    }
}

// Basic QR Scanner View using UIKit integration
struct QRScannerView: UIViewControllerRepresentable {
    var completion: (String) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = QRScannerViewController()
        viewController.completion = completion
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    // This is a placeholder - you would need to implement the actual QR scanner
    class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var completion: ((String) -> Void)?
        var captureSession: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?
        var currentPosition: AVCaptureDevice.Position = .back
        
        override func viewDidLoad() {
            super.viewDidLoad()
            setupCamera()
            setupFlipButton()
        }
        
        func setupFlipButton() {
            // Create flip camera button
            let flipButton = UIButton(type: .system)
            flipButton.setImage(UIImage(systemName: "camera.rotate"), for: .normal)
            flipButton.tintColor = .white
            flipButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            flipButton.layer.cornerRadius = 25
            flipButton.addTarget(self, action: #selector(flipCamera), for: .touchUpInside)
            
            // Add button to view
            view.addSubview(flipButton)
            flipButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                flipButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
                flipButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
                flipButton.widthAnchor.constraint(equalToConstant: 50),
                flipButton.heightAnchor.constraint(equalToConstant: 50)
            ])
        }
        
        @objc func flipCamera() {
            // Toggle camera position
            currentPosition = currentPosition == .back ? .front : .back
            
            // Stop current session
            captureSession?.stopRunning()
            
            // Remove existing inputs
            if let inputs = captureSession?.inputs {
                for input in inputs {
                    captureSession?.removeInput(input)
                }
            }
            
            // Setup with new camera
            setupCameraInput()
            
            // Start session again
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession?.startRunning()
            }
        }
        
        func setupCamera() {
            let captureSession = AVCaptureSession()
            self.captureSession = captureSession
            
            setupCameraInput()
            
            let metadataOutput = AVCaptureMetadataOutput()
            if captureSession.canAddOutput(metadataOutput) {
                captureSession.addOutput(metadataOutput)
                
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            } else {
                print("Could not add metadata output")
                return
            }
            
            // Add preview layer
            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            self.previewLayer = previewLayer
            previewLayer.frame = view.layer.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
            
            // Start running
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession?.startRunning()
            }
        }
        
        func setupCameraInput() {
            guard let captureSession = captureSession else { return }
            
            // Get video capture device for the specified position
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: currentPosition
            )
            
            guard let videoCaptureDevice = discoverySession.devices.first else {
                print("Camera not available for position: \(currentPosition)")
                return
            }
            
            do {
                let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
                if captureSession.canAddInput(videoInput) {
                    captureSession.addInput(videoInput)
                } else {
                    print("Could not add video input")
                }
            } catch {
                print("Error setting up camera: \(error)")
            }
        }
        
        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.layer.bounds
        }
        
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            // Get the QR code data
            if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
               let stringValue = metadataObject.stringValue {
                
                // Stop scanning
                captureSession?.stopRunning()
                
                // Call completion with scanned value
                completion?(stringValue)
            }
        }
        
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            captureSession?.stopRunning()
        }
    }
}

#Preview {
    FaucetView(
        isScanning: .constant(false),
        showingSendForm: .constant(false),
        selectionGenerator: UISelectionFeedbackGenerator(),
        bleService: BLEService()
    )
    .padding()
}

