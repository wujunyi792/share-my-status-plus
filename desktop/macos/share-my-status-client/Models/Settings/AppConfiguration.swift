//
//  AppConfiguration.swift
//  share-my-status-client
//
//  Created by Refactor on 2025-01-07.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Application Configuration

@MainActor
class AppConfiguration: ObservableObject {
    // MARK: - Network Configuration
    @Published var secretKey: String {
        didSet {
            UserDefaults.standard.set(secretKey, forKey: "secretKey")
        }
    }
    
    @Published var endpointURL: String {
        didSet {
            UserDefaults.standard.set(endpointURL, forKey: "endpointURL")
        }
    }
    
    // MARK: - Feature Toggles
    @Published var isReportingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isReportingEnabled, forKey: "isReportingEnabled")
        }
    }
    
    @Published var musicReportingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(musicReportingEnabled, forKey: "musicReportingEnabled")
        }
    }
    
    @Published var systemReportingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(systemReportingEnabled, forKey: "systemReportingEnabled")
        }
    }
    
    @Published var activityReportingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(activityReportingEnabled, forKey: "activityReportingEnabled")
        }
    }
    
    // MARK: - Statistics Authorization
    @Published var musicStatsAuthorized: Bool {
        didSet {
            UserDefaults.standard.set(musicStatsAuthorized, forKey: "musicStatsAuthorized")
        }
    }
    
    // MARK: - App Whitelist/Blacklist
    @Published var musicAppWhitelist: [String] {
        didSet {
            UserDefaults.standard.set(musicAppWhitelist, forKey: "musicAppWhitelist")
        }
    }
    
    @Published var activityAppBlacklist: [String] {
        didSet {
            UserDefaults.standard.set(activityAppBlacklist, forKey: "activityAppBlacklist")
        }
    }
    
    @Published var activityGroups: [ActivityGroup] {
        didSet {
            if let encoded = try? JSONEncoder().encode(activityGroups) {
                UserDefaults.standard.set(encoded, forKey: "activityGroups")
            }
        }
    }
    
    // MARK: - Report Interval Settings (deprecated, kept for backward compatibility)
    @Published var reportInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(reportInterval, forKey: "reportInterval")
        }
    }
    
    // MARK: - Polling Interval Settings
    /// System monitoring polling interval (in seconds)
    @Published var systemPollingInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(systemPollingInterval, forKey: "systemPollingInterval")
        }
    }
    
    /// Activity detection polling interval (in seconds)
    @Published var activityPollingInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(activityPollingInterval, forKey: "activityPollingInterval")
        }
    }
    
    // MARK: - Initialization
    init() {
        // Network configuration
        self.secretKey = UserDefaults.standard.string(forKey: "secretKey") ?? DefaultSettings.secretKey
        self.endpointURL = UserDefaults.standard.string(forKey: "endpointURL") ?? DefaultSettings.endpointURL
        
        // Feature toggles
        self.isReportingEnabled = UserDefaults.standard.object(forKey: "isReportingEnabled") as? Bool ?? DefaultSettings.isReportingEnabled
        self.musicReportingEnabled = UserDefaults.standard.object(forKey: "musicReportingEnabled") as? Bool ?? DefaultSettings.musicReportingEnabled
        self.systemReportingEnabled = UserDefaults.standard.object(forKey: "systemReportingEnabled") as? Bool ?? DefaultSettings.systemReportingEnabled
        self.activityReportingEnabled = UserDefaults.standard.object(forKey: "activityReportingEnabled") as? Bool ?? DefaultSettings.activityReportingEnabled
        
        // Statistics authorization
        self.musicStatsAuthorized = UserDefaults.standard.object(forKey: "musicStatsAuthorized") as? Bool ?? DefaultSettings.musicStatsAuthorized
        
        // App lists
        self.musicAppWhitelist = UserDefaults.standard.stringArray(forKey: "musicAppWhitelist") ?? DefaultSettings.musicAppWhitelist
        self.activityAppBlacklist = UserDefaults.standard.stringArray(forKey: "activityAppBlacklist") ?? DefaultSettings.activityAppBlacklist
        
        // Activity groups
        if let data = UserDefaults.standard.data(forKey: "activityGroups"),
           let groups = try? JSONDecoder().decode([ActivityGroup].self, from: data) {
            self.activityGroups = groups
        } else {
            self.activityGroups = DefaultSettings.activityGroups
        }
        
        // Report interval (seconds) - kept for backward compatibility
        self.reportInterval = UserDefaults.standard.object(forKey: "reportInterval") as? TimeInterval ?? DefaultSettings.reportInterval
        
        // Polling intervals for each service (seconds)
        self.systemPollingInterval = UserDefaults.standard.object(forKey: "systemPollingInterval") as? TimeInterval ?? DefaultSettings.systemPollingInterval
        self.activityPollingInterval = UserDefaults.standard.object(forKey: "activityPollingInterval") as? TimeInterval ?? DefaultSettings.activityPollingInterval
    }
    
    // MARK: - Convenience Methods
    func isValidConfiguration() -> Bool {
        return !secretKey.isEmpty && !endpointURL.isEmpty && URL(string: endpointURL) != nil
    }
    
    func resetToDefaults() {
        let defaults = UserDefaults.standard
        let keys = [
            "secretKey", "endpointURL", "isReportingEnabled",
            "musicReportingEnabled", "systemReportingEnabled", "activityReportingEnabled",
            "musicStatsAuthorized", "musicAppWhitelist", "activityAppBlacklist",
            "activityGroups", "reportInterval",
            "systemPollingInterval", "activityPollingInterval"
        ]
        
        keys.forEach { defaults.removeObject(forKey: $0) }
        
        // Reset to default values
        self.secretKey = DefaultSettings.secretKey
        self.endpointURL = DefaultSettings.endpointURL
        self.isReportingEnabled = DefaultSettings.isReportingEnabled
        self.musicReportingEnabled = DefaultSettings.musicReportingEnabled
        self.systemReportingEnabled = DefaultSettings.systemReportingEnabled
        self.activityReportingEnabled = DefaultSettings.activityReportingEnabled
        self.musicStatsAuthorized = DefaultSettings.musicStatsAuthorized
        self.musicAppWhitelist = DefaultSettings.musicAppWhitelist
        self.activityAppBlacklist = DefaultSettings.activityAppBlacklist
        self.activityGroups = DefaultSettings.activityGroups
        self.reportInterval = DefaultSettings.reportInterval
        self.systemPollingInterval = DefaultSettings.systemPollingInterval
        self.activityPollingInterval = DefaultSettings.activityPollingInterval
    }
}

