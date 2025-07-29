//
//  CameraView.swift
//  PerformanceAnalytics
//
//  Created by Jacob Bartlett on 21/07/2025.
//

import SwiftUI
import AVFoundation
import Combine

struct CameraView: View {
    
    private let analyticsService: AnalyticsService
    @StateObject private var cameraManager = CameraManager()
    
    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if cameraManager.isAuthorized {
                    CameraPreviewView(session: cameraManager.session)
                        .ignoresSafeArea()
                } else if cameraManager.permissionDenied {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        
                        Text("Camera Access Denied")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Please enable camera access in Settings to use this feature.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Open Settings") {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Requesting Camera Access...")
                            .font(.headline)
                    }
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 5) {
                            Text("Camera Performance")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("FPS: \(cameraManager.currentFPS, specifier: "%.1f")")
                                .font(.caption)
                                .monospaced()
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding()
                    }
                }
            }
            .navigationTitle("Camera")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            cameraManager.requestPermission()
            cameraManager.startSession()
            analyticsService.track(event: "camera_started", properties: [
                "camera_position": "back"
            ])
        }
        .onDisappear {
            cameraManager.stopSession()
            analyticsService.track(event: "camera_stopped", properties: [
                "session_duration": cameraManager.sessionDuration
            ])
        }
    }
}

class CameraManager: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var permissionDenied = false
    @Published var currentFPS: Double = 0.0
    
    let session = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var lastFrameTime = CACurrentMediaTime()
    private var frameCount = 0
    private var sessionStartTime: Date?
    
    var sessionDuration: TimeInterval {
        guard let startTime = sessionStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    override init() {
        super.init()
        setupCamera()
    }
    
    func requestPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.isAuthorized = true
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                    self.permissionDenied = !granted
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.permissionDenied = true
            }
        @unknown default:
            DispatchQueue.main.async {
                self.permissionDenied = true
            }
        }
    }
    
    private func setupCamera() {
        session.sessionPreset = .high
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.frame.processing"))
        output.alwaysDiscardsLateVideoFrames = true
        
        if session.canAddOutput(output) {
            session.addOutput(output)
            self.videoOutput = output
        }
    }
    
    func startSession() {
        guard !session.isRunning else { return }
        sessionStartTime = Date()
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }
    
    func stopSession() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameCount += 1
        let currentTime = CACurrentMediaTime()
        
        if currentTime - lastFrameTime >= 1.0 {
            let fps = Double(frameCount) / (currentTime - lastFrameTime)
            DispatchQueue.main.async {
                self.currentFPS = fps
            }
            frameCount = 0
            lastFrameTime = currentTime
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.frame
        }
    }
}