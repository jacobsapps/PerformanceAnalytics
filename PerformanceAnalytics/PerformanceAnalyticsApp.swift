//
//  PerformanceAnalyticsApp.swift
//  PerformanceAnalytics
//
//  Created by Jacob Bartlett on 21/07/2025.
//

import SwiftUI

@main
struct PerformanceAnalyticsApp: App {
    private let analyticsService: AnalyticsService
    @StateObject private var lifecycleService: AppLifecycleService
    @AppStorage("user_id") private var storedUserId: String = ""
    
    init() {
        let analyticsService = MixpanelAnalyticsService()
        self.analyticsService = analyticsService
        self._lifecycleService = StateObject(wrappedValue: AppLifecycleService(analyticsService: analyticsService))
        
        let userId: String
        if storedUserId.isEmpty {
            userId = UUID().uuidString
            storedUserId = userId
        } else {
            userId = storedUserId
        }
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
            .environmentObject(lifecycleService)
        }
    }
}
