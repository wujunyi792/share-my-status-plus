//
//  MonitoringProtocols.swift
//  share-my-status-client
//
//  Created on 2025-01-07.
//

import Foundation

/// Monitoring type distinguishes between polling and event-driven monitors
enum MonitoringType {
    case polling    // Regular interval-based monitoring (System, Activity)
    case eventDriven // Event-based monitoring (Music)
}

/// Base protocol for all monitoring services
protocol MonitoringService: Actor {
    /// Type of monitoring (polling or event-driven)
    var monitoringType: MonitoringType { get }
    
    /// Whether the service is currently active
    func isActive() -> Bool
    
    /// Start the monitoring service
    func start() async throws
    
    /// Stop the monitoring service
    func stop() async
}

/// Protocol for polling-based monitoring services
protocol PollingMonitoringService: MonitoringService {
    /// Current polling interval in seconds
    var pollingInterval: TimeInterval { get }
    
    /// Update the polling interval
    func updatePollingInterval(_ interval: TimeInterval) async
}

/// Protocol for event-driven monitoring services
protocol EventDrivenMonitoringService: MonitoringService {
    /// Callback type for events
    associatedtype EventData
    
    /// Register a callback for events
    func registerCallback(_ callback: @escaping (EventData?) -> Void) async
}

/// Monitoring configuration for each service
struct MonitoringConfiguration {
    let isEnabled: Bool
    let pollingInterval: TimeInterval?  // Only for polling services
    
    init(isEnabled: Bool, pollingInterval: TimeInterval? = nil) {
        self.isEnabled = isEnabled
        self.pollingInterval = pollingInterval
    }
}
