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
    @State private var progressTrackingTask: Task<Void, Never>?
    
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
                            Text(cameraManager.debugInfo)
                                .font(.caption2)
                                .foregroundColor(.yellow)
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
            analyticsService.track(event: "Camera - Started", properties: [
                "camera_position": "back"
            ])
            startProgressTracking()
        }
        .onDisappear {
            stopProgressTracking()
            cameraManager.stopSession()
            analyticsService.track(event: "Camera - Stopped", properties: [
                "session_duration": cameraManager.sessionDuration
            ])
        }
    }
    
    private func startProgressTracking() {
        progressTrackingTask = Task.detached {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                if !Task.isCancelled {
                    await MainActor.run {
                        analyticsService.track(event: "Camera - In Progress", properties: [
                            "is_authorized": cameraManager.isAuthorized,
                            "permission_denied": cameraManager.permissionDenied,
                            "current_fps": cameraManager.currentFPS,
                            "session_duration": cameraManager.sessionDuration
                        ])
                    }
                }
            }
        }
    }
    
    private func stopProgressTracking() {
        progressTrackingTask?.cancel()
        progressTrackingTask = nil
    }
}

class CameraManager: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var permissionDenied = false
    @Published var currentFPS: Double = 0.0
    @Published var debugInfo = "Initializing camera..."
    
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
        debugInfo = "Requesting camera permission..."
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.debugInfo = "Camera permission already granted"
                self.isAuthorized = true
                self.startSession()
            }
        case .notDetermined:
            debugInfo = "Camera permission not determined, requesting..."
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                    self.permissionDenied = !granted
                    self.debugInfo = granted ? "Camera permission granted" : "Camera permission denied"
                    if granted {
                        self.startSession()
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.permissionDenied = true
                self.debugInfo = "Camera permission denied or restricted"
            }
        @unknown default:
            DispatchQueue.main.async {
                self.permissionDenied = true
                self.debugInfo = "Unknown camera permission status"
            }
        }
    }
    
    private func setupCamera() {
        debugInfo = "Setting up camera session..."
        session.beginConfiguration()
        
        session.sessionPreset = .high
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            debugInfo = "Failed to get camera device"
            session.commitConfiguration()
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                debugInfo = "Camera input added successfully"
            } else {
                debugInfo = "Cannot add camera input to session"
                session.commitConfiguration()
                return
            }
        } catch {
            debugInfo = "Failed to create camera input: \(error.localizedDescription)"
            session.commitConfiguration()
            return
        }
        
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.frame.processing"))
        output.alwaysDiscardsLateVideoFrames = true
        
        if session.canAddOutput(output) {
            session.addOutput(output)
            self.videoOutput = output
            debugInfo = "Camera setup completed successfully"
        } else {
            debugInfo = "Cannot add video output to session"
        }
        
        session.commitConfiguration()
    }
    
    func startSession() {
        guard !session.isRunning else { 
            debugInfo = "Session already running"
            return 
        }
        sessionStartTime = Date()
        debugInfo = "Starting camera session..."
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
            DispatchQueue.main.async {
                self.debugInfo = self.session.isRunning ? "Camera session running" : "Failed to start camera session"
            }
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
    
    func makeUIView(context: Context) -> PreviewView {
        let previewView = PreviewView()
        previewView.previewLayer.session = session
        previewView.previewLayer.videoGravity = .resizeAspectFill
        
        // Set up orientation handling
        if let connection = previewView.previewLayer.connection {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
        
        return previewView
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        // Update orientation if needed
        if let connection = uiView.previewLayer.connection {
            if connection.isVideoOrientationSupported {
                let orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait
                switch orientation {
                case .portrait:
                    connection.videoOrientation = .portrait
                case .portraitUpsideDown:
                    connection.videoOrientation = .portraitUpsideDown
                case .landscapeLeft:
                    connection.videoOrientation = .landscapeLeft
                case .landscapeRight:
                    connection.videoOrientation = .landscapeRight
                default:
                    connection.videoOrientation = .portrait
                }
            }
        }
    }
}

class PreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}
