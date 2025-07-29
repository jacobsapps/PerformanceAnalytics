//
//  MixpanelAnalyticsService.swift
//  PerformanceAnalytics
//
//  Created by Jacob Bartlett on 21/07/2025.
//

import Foundation
import Mixpanel

/// Mixpanel implementation of AnalyticsService with automatic performance metrics integration
class MixpanelAnalyticsService: AnalyticsService {
    
    private let performanceService = SystemPerformanceService.shared
    private let mixpanelInstance: MixpanelInstance
    
    /// Initialize Mixpanel analytics service with API key
    /// Replace YOUR_API_KEY_HERE with your actual Mixpanel project API key
    init() {
        let MIXPANEL_API_KEY = "YOUR_API_KEY_HERE"
        self.mixpanelInstance = Mixpanel.initialize(token: MIXPANEL_API_KEY, trackAutomaticEvents: true)
    }
    
    /// Track an event with automatic performance metrics attachment
    /// All events automatically include comprehensive system performance data
    /// - Parameters:
    ///   - event: The event name to track
    ///   - properties: Optional dictionary of event-specific properties
    func track(event: String, properties: [String: Any]? = nil) {
        var enrichedProperties = performanceService.getAllMetrics()
        
        // Merge custom properties with performance metrics
        if let customProperties = properties {
            enrichedProperties.merge(customProperties) { (_, new) in new }
        }
        
        let mixpanelProperties = enrichedProperties.compactMapValues { $0 as? MixpanelType }
        mixpanelInstance.track(event: event, properties: mixpanelProperties)
    }
    
    /// Identify a user for analytics tracking
    /// - Parameter userId: The unique identifier for the user
    func identify(userId: String) {
        mixpanelInstance.identify(distinctId: userId)
    }
    
    /// Identify a user with properties for analytics tracking
    /// - Parameters:
    ///   - userId: The unique identifier for the user
    ///   - properties: Dictionary of user properties to set
    func identifyUser(userId: String, properties: [String: Any]) {
        mixpanelInstance.identify(distinctId: userId)
        
        var userProperties = performanceService.getStorageUserProperties()
        userProperties.merge(properties) { (_, new) in new }
        
        let mixpanelProperties = userProperties.compactMapValues { $0 as? MixpanelType }
        mixpanelInstance.people.set(properties: mixpanelProperties)
    }
    
    /// Set user properties for analytics with current performance context
    /// Automatically includes device performance metrics as user properties
    /// - Parameter properties: Dictionary of user properties to set
    func setUserProperties(_ properties: [String: Any]) {
        var enrichedProperties = performanceService.getAllMetrics()
        enrichedProperties.merge(properties) { (_, new) in new }
        
        let mixpanelProperties = enrichedProperties.compactMapValues { $0 as? MixpanelType }
        mixpanelInstance.people.set(properties: mixpanelProperties)
    }
}
