//
//  AppLifecycleService.swift
//  PerformanceAnalytics
//
//  Created by Jacob Bartlett on 21/07/2025.
//

import SwiftUI
import Combine
import UIKit

/// Service to track app lifecycle events and send analytics
class AppLifecycleService: ObservableObject {
    
    private let analyticsService: AnalyticsService
    private var cancellables = Set<AnyCancellable>()
    private var appLaunchTime: Date?
    private var backgroundTime: Date?
    
    @Published var currentState: AppState = .unknown
    
    enum AppState {
        case active
        case inactive
        case background
        case unknown
    }
    
    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
        self.appLaunchTime = Date()
        setupLifecycleObservers()
        
        // Track app launch
        analyticsService.track(event: "Lifecycle - Launched", properties: [
            "launch_time": Date().timeIntervalSince1970
        ])
    }
    
    private func setupLifecycleObservers() {
        NotificationCenter.default.publisher(for: UIScene.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleWillEnterForeground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIScene.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleDidEnterBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.handleWillTerminate()
            }
            .store(in: &cancellables)
    }
    
    private func handleWillEnterForeground() {
        currentState = .inactive
        
        let backgroundDuration = backgroundTime.map { Date().timeIntervalSince($0) } ?? 0
        
        analyticsService.track(event: "Lifecycle - Foregrounded", properties: [
            "foreground_time": Date().timeIntervalSince1970,
            "background_duration": backgroundDuration,
            "app_uptime": appLaunchTime.map { Date().timeIntervalSince($0) } ?? 0
        ])
        
        backgroundTime = nil
    }
    
    private func handleDidEnterBackground() {
        currentState = .background
        backgroundTime = Date()
        
        let sessionDuration = appLaunchTime.map { Date().timeIntervalSince($0) } ?? 0
        
        analyticsService.track(event: "Lifecycle - Backgrounded", properties: [
            "background_time": Date().timeIntervalSince1970,
            "session_duration": sessionDuration,
            "app_uptime": sessionDuration
        ])
    }
    
    private func handleWillTerminate() {
        let totalSessionDuration = appLaunchTime.map { Date().timeIntervalSince($0) } ?? 0
        
        analyticsService.track(event: "Lifecycle - Terminated", properties: [
            "terminate_time": Date().timeIntervalSince1970,
            "total_session_duration": totalSessionDuration
        ])
    }
    
    deinit {
        cancellables.removeAll()
    }
}
