//
//  AnimationView.swift
//  PerformanceAnalytics
//
//  Created by Jacob Bartlett on 21/07/2025.
//

import SwiftUI
import Combine

struct AnimationView: View {
    
    private let analyticsService: AnalyticsService
    @State private var isAnimating = false
    @State private var animationSpeed: Double = 1.0
    @State private var lineCount = 200
    @State private var animationStartTime: Date?
    @State private var progressTrackingTask: Task<Void, Never>?
    
    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // Controls
                VStack(spacing: 15) {
                    HStack {
                        Text("Line Count: \(lineCount)")
                            .fontWeight(.semibold)
                        Spacer()
                        Stepper("", value: $lineCount, in: 50...500, step: 50)
                    }
                    
                    HStack {
                        Text("Speed: \(animationSpeed, specifier: "%.1f")x")
                            .fontWeight(.semibold)
                        Spacer()
                        Slider(value: $animationSpeed, in: 0.1...3.0, step: 0.1)
                            .frame(width: 120)
                    }
                    
                    Button(action: toggleAnimation) {
                        Text(isAnimating ? "Stop Animation" : "Start Animation")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(isAnimating ? Color.red : Color.green)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Animation Canvas
                GeometryReader { geometry in
                    AnimationCanvas(
                        isAnimating: isAnimating,
                        lineCount: lineCount,
                        speed: animationSpeed,
                        canvasSize: geometry.size
                    )
                }
                .background(Color.black)
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Stats
                VStack(spacing: 8) {
                    Text("Animation Statistics")
                        .font(.headline)
                    
                    HStack {
                        Text("Status:")
                        Spacer()
                        Text(isAnimating ? "RUNNING" : "STOPPED")
                            .fontWeight(.bold)
                            .foregroundColor(isAnimating ? .green : .red)
                    }
                    
                    if let startTime = animationStartTime {
                        HStack {
                            Text("Duration:")
                            Spacer()
                            Text("\(Date().timeIntervalSince(startTime), specifier: "%.1f")s")
                                .monospaced()
                        }
                    }
                    
                    HStack {
                        Text("Render Load:")
                        Spacer()
                        Text("\(calculateRenderLoad())%")
                            .monospaced()
                            .foregroundColor(calculateRenderLoad() > 80 ? .red : .primary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Animation")
        }
        .onAppear {
            analyticsService.track(event: "Animation Tab - Viewed", properties: nil)
            startProgressTracking()
        }
        .onDisappear {
            stopProgressTracking()
            if isAnimating {
                stopAnimation()
            }
        }
    }
    
    private func toggleAnimation() {
        if isAnimating {
            stopAnimation()
        } else {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        isAnimating = true
        animationStartTime = Date()
        
        analyticsService.track(event: "Animation - Started", properties: [
            "line_count": lineCount,
            "animation_speed": animationSpeed,
            "expected_render_load": calculateRenderLoad()
        ])
    }
    
    private func stopAnimation() {
        guard isAnimating else { return }
        
        isAnimating = false
        let duration = animationStartTime.map { Date().timeIntervalSince($0) } ?? 0
        
        analyticsService.track(event: "Animation - Stopped", properties: [
            "line_count": lineCount,
            "animation_speed": animationSpeed,
            "duration": duration,
            "render_load": calculateRenderLoad()
        ])
        
        animationStartTime = nil
    }
    
    private func calculateRenderLoad() -> Int {
        // Estimate render load based on line count and speed
        let baseLoad = Double(lineCount) / 500.0 * 100.0
        let speedMultiplier = animationSpeed
        return Int(min(baseLoad * speedMultiplier, 100.0))
    }
    
    private func startProgressTracking() {
        progressTrackingTask = Task.detached {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                if !Task.isCancelled {
                    await MainActor.run {
                        analyticsService.track(event: "Animation Tab - In Progress", properties: [
                            "is_animating": isAnimating,
                            "line_count": lineCount,
                            "animation_speed": animationSpeed,
                            "render_load": calculateRenderLoad(),
                            "duration": animationStartTime.map { Date().timeIntervalSince($0) } ?? 0
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

struct AnimationCanvas: View {
    let isAnimating: Bool
    let lineCount: Int
    let speed: Double
    let canvasSize: CGSize
    
    @State private var animationOffset: Double = 0
    
    var body: some View {
        Canvas { context, size in
            let centerX = size.width / 2
            let centerY = size.height / 2
            
            for i in 0..<lineCount {
                let angle = (Double(i) / Double(lineCount)) * 2 * .pi
                let radius = min(size.width, size.height) * 0.4
                
                // Create multiple moving line segments per "line"
                for segment in 0..<3 {
                    let segmentOffset = Double(segment) * 0.3 + animationOffset
                    let dynamicRadius = radius + sin(segmentOffset + angle * 2) * 30
                    
                    let startX = centerX + cos(angle + segmentOffset * 0.1) * (dynamicRadius - 40)
                    let startY = centerY + sin(angle + segmentOffset * 0.1) * (dynamicRadius - 40)
                    
                    let endX = centerX + cos(angle + segmentOffset * 0.1) * dynamicRadius
                    let endY = centerY + sin(angle + segmentOffset * 0.1) * dynamicRadius
                    
                    // Color based on position and time
                    let hue = (angle + segmentOffset) / (2 * .pi)
                    let color = Color(hue: hue.truncatingRemainder(dividingBy: 1.0), 
                                    saturation: 0.8, 
                                    brightness: 0.9)
                    
                    var path = Path()
                    path.move(to: CGPoint(x: startX, y: startY))
                    path.addLine(to: CGPoint(x: endX, y: endY))
                    
                    context.stroke(path, with: .color(color), lineWidth: 2)
                }
                
                // Add some connecting lines between segments for complexity
                if i % 10 == 0 {
                    let nextIndex = (i + 10) % lineCount
                    let angle1 = (Double(i) / Double(lineCount)) * 2 * .pi
                    let angle2 = (Double(nextIndex) / Double(lineCount)) * 2 * .pi
                    let connectRadius = radius * 0.8
                    
                    let x1 = centerX + cos(angle1 + animationOffset * 0.05) * connectRadius
                    let y1 = centerY + sin(angle1 + animationOffset * 0.05) * connectRadius
                    let x2 = centerX + cos(angle2 + animationOffset * 0.05) * connectRadius
                    let y2 = centerY + sin(angle2 + animationOffset * 0.05) * connectRadius
                    
                    var connectPath = Path()
                    connectPath.move(to: CGPoint(x: x1, y: y1))
                    connectPath.addLine(to: CGPoint(x: x2, y: y2))
                    
                    context.stroke(connectPath, with: .color(.white.opacity(0.3)), lineWidth: 1)
                }
            }
        }
        .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
            if isAnimating {
                animationOffset += 0.05 * speed
            }
        }
    }
}
