//
//  CPUTestView.swift
//  PerformanceAnalytics
//
//  Created by Jacob Bartlett on 21/07/2025.
//

import SwiftUI

struct CPUTestView: View {
    
    private let analyticsService: AnalyticsService
    @State private var showingStressModal = false
    @State private var progressTrackingTask: Task<Void, Never>?
    
    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                
                Image(systemName: "cpu")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .foregroundColor(.blue)
                
                VStack(spacing: 20) {
                    Text("CPU Performance Test")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Press the button below to start an extremely expensive parallel computation that will stress all CPU cores.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    VStack(spacing: 10) {
                        Text("Device Info")
                            .font(.headline)
                        Text("CPU Cores: \(ProcessInfo.processInfo.processorCount)")
                        Text("Processor: Unknown")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Button(action: {
                    showingStressModal = true
                }) {
                    Text("Start CPU Stress Test")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
                
                Spacer()
                
            }
            .padding()
            .navigationTitle("CPU Test")
        }
        .sheet(isPresented: $showingStressModal) {
            CPUStressModal(isPresented: $showingStressModal, analyticsService: analyticsService)
        }
        .onAppear {
            analyticsService.track(event: "CPU Tab - Viewed", properties: nil)
            startProgressTracking()
        }
        .onDisappear {
            stopProgressTracking()
        }
    }
    
    private func startProgressTracking() {
        progressTrackingTask = Task.detached {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                if !Task.isCancelled {
                    await MainActor.run {
                        analyticsService.track(event: "CPU Tab - In Progress", properties: [
                            "tab_active": true,
                            "modal_showing": showingStressModal
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
