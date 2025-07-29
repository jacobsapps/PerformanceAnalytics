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
    
    init(isPresented: Binding<Bool>, analyticsService: AnalyticsService) {
        self._isPresented = isPresented
        self.analyticsService = analyticsService
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        stopStressing()
                        isPresented = false
                    }
                }
            }
        }
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
        analyticsService.track(event: "cpu_test_started", properties: [
            "core_count": ProcessInfo.processInfo.processorCount
        ])
        
        let coreCount = ProcessInfo.processInfo.processorCount
        stressTasks.removeAll()
        
        for coreIndex in 0..<coreCount {
            let task = Task {
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
    }
    
    private func stopStressing() {
        guard isStressing else { return }
        
        isStressing = false
        analyticsService.track(event: "cpu_test_stopped", properties: [
            "core_count": ProcessInfo.processInfo.processorCount
        ])
        
        for task in stressTasks {
            task.cancel()
        }
        stressTasks.removeAll()
    }
}