//
//  FaucetView.swift
//  Own Pay
//
//  Created by Ashwin Ravikumar on 11/03/2025.
//

import SwiftUI
import AVFoundation // Add this import for camera access

struct FaucetView: View {
    @Binding var isScanning: Bool
    @Binding var showingSendForm: Bool
    let selectionGenerator: UISelectionFeedbackGenerator
    let bleService: BLEService
    @State private var showingQRScanner = false // New state for QR scanner
    
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
                showingQRScanner = true // Show camera scanner
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
        }
        .sheet(isPresented: $showingQRScanner) {
            // This would be your QR code scanner view
            QRScannerView { result in
                print("Scanned wallet address: \(result)")
                showingQRScanner = false
            }
        }
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
        
        override func viewDidLoad() {
            super.viewDidLoad()
            setupCamera()
        }
        
        func setupCamera() {
            let captureSession = AVCaptureSession()
            self.captureSession = captureSession
            
            guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
                print("Camera not available")
                return
            }
            
            do {
                let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
                if captureSession.canAddInput(videoInput) {
                    captureSession.addInput(videoInput)
                } else {
                    print("Could not add video input")
                    return
                }
                
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
                previewLayer.frame = view.layer.bounds
                previewLayer.videoGravity = .resizeAspectFill
                view.layer.addSublayer(previewLayer)
                
                // Start running
                DispatchQueue.global(qos: .userInitiated).async {
                    self.captureSession?.startRunning()
                }
            } catch {
                print("Error setting up camera: \(error)")
            }
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
