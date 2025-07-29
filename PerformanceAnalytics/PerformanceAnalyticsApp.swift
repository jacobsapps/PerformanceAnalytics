//
//  PerformanceAnalyticsApp.swift
//  PerformanceAnalytics
//
//  Created by Jacob Bartlett on 21/07/2025.
//

import SwiftUI

@main
struct PerformanceAnalyticsApp: App {
    private let analyticsService: AnalyticsService = MixpanelAnalyticsService()
    
    init() {
        let userId = UUID().uuidString
        analyticsService.identifyUser(userId: userId, properties: [:])
    }
    
    var body: some Scene {
        WindowGroup {
            TabView {
                CPUTestView(analyticsService: analyticsService)
                    .tabItem {
                        Image(systemName: "cpu")
                        Text("CPU Test")
                    }
                
                CameraView(analyticsService: analyticsService)
                    .tabItem {
                        Image(systemName: "camera")
                        Text("Camera")
                    }
                
                FormsView(analyticsService: analyticsService)
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("Forms")
                    }
                
                AnimationView(analyticsService: analyticsService)
                    .tabItem {
                        Image(systemName: "sparkles")
                        Text("Animation")
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
