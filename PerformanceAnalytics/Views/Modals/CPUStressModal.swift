//
//  CPUStressModal.swift
//  PerformanceAnalytics
//
//  Created by Jacob Bartlett on 21/07/2025.
//

import SwiftUI
import Foundation

struct CPUStressModal: View {
    
    @Binding var isPresented: Bool
    private let analyticsService: AnalyticsService
    @State private var isStressing = false
    @State private var stressTasks: [Task<Void, Never>] = []
    @State private var progressTrackingTask: Task<Void, Never>?
    
    init(isPresented: Binding<Bool>, analyticsService: AnalyticsService) {
        self._isPresented = isPresented
        self.analyticsService = analyticsService
    }
    
    var body: some View {
        VStack(spacing: 30) {
            
            HStack {
                Spacer()
                Button("Close") {
                    stopStressing()
                    isPresented = false
                }
                .font(.headline)
            }
            .padding(.horizontal)
            
            Text("CPU Stress Test")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("This will create extremely expensive parallel computations across all CPU cores to test thermal and performance impact.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(spacing: 10) {
                Text("CPU Cores: \(ProcessInfo.processInfo.processorCount)")
                    .font(.headline)
                
                Text("Status: \(isStressing ? "STRESSING CPU" : "IDLE")")
                    .font(.headline)
                    .foregroundColor(isStressing ? .red : .green)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            Spacer()
            
        }
        .padding()
        .onAppear {
            startStressing()
        }
        .onDisappear {
            stopStressing()
        }
    }
    
    private func startStressing() {
        guard !isStressing else { return }
        
        isStressing = true
        analyticsService.track(event: "CPU Test - Started", properties: [
            "core_count": ProcessInfo.processInfo.processorCount,
            "active_core_count": ProcessInfo.processInfo.activeProcessorCount
        ])
        
        let backgroundCores = ProcessInfo.processInfo.activeProcessorCount - 1
        stressTasks.removeAll()
        
        for coreIndex in 0..<backgroundCores {
            let task = Task.detached {
                var counter = 0
                while !Task.isCancelled {
                    counter += 1
                    // Prevent compiler optimization while maintaining stress
                    if counter % 1000000 == 0 {
                        _ = counter
                    }
                }
            }
            stressTasks.append(task)
        }
        
        // Start periodic progress tracking
        progressTrackingTask = Task.detached {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                if !Task.isCancelled {
                    await MainActor.run {
                        analyticsService.track(event: "CPU Test - In Progress", properties: [
                            "core_count": ProcessInfo.processInfo.processorCount,
                            "active_core_count": ProcessInfo.processInfo.activeProcessorCount,
                            "active_tasks": stressTasks.count
                        ])
                    }
                }
            }
        }
    }
    
    private func stopStressing() {
        guard isStressing else { return }
        
        isStressing = false
        analyticsService.track(event: "CPU Test - Stopped", properties: [
            "core_count": ProcessInfo.processInfo.processorCount,
            "active_core_count": ProcessInfo.processInfo.activeProcessorCount
        ])
        
        // Stop progress tracking
        progressTrackingTask?.cancel()
        progressTrackingTask = nil
        
        for task in stressTasks {
            task.cancel()
        }
        stressTasks.removeAll()
    }
}
