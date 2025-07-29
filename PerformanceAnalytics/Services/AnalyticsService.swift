//
//  AnalyticsService.swift
//  PerformanceAnalytics
//
//  Created by Jacob Bartlett on 21/07/2025.
//

import Foundation

/// Protocol defining analytics service interface for tracking user events and performance metrics
protocol AnalyticsService {
    
    /// Track an event with optional properties
    /// - Parameters:
    ///   - event: The event name to track
    ///   - properties: Optional dictionary of event properties
    func track(event: String, properties: [String: Any]?)
    
    /// Identify a user for analytics tracking
    /// - Parameter userId: The unique identifier for the user
    func identify(userId: String)
    
    /// Identify a user with properties for analytics tracking
    /// - Parameters:
    ///   - userId: The unique identifier for the user
    ///   - properties: Dictionary of user properties to set
    func identifyUser(userId: String, properties: [String: Any])
    
    /// Set user properties for analytics
    /// - Parameter properties: Dictionary of user properties to set
    func setUserProperties(_ properties: [String: Any])
}
