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
    
    // MARK: - Activity Tag Mapping Rules
    @Published var activityRules: [ActivityRule] {
        didSet {
            if let encoded = try? JSONEncoder().encode(activityRules) {
                UserDefaults.standard.set(encoded, forKey: "activityRules")
            }
        }
    }
    
    // MARK: - Report Interval Settings
    @Published var reportInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(reportInterval, forKey: "reportInterval")
        }
    }
    
    // MARK: - Initialization
    init() {
        // Network configuration
        self.secretKey = UserDefaults.standard.string(forKey: "secretKey") ?? ""
        self.endpointURL = UserDefaults.standard.string(forKey: "endpointURL") ?? "https://api.example.com/v1/state/report"
        
        // Feature toggles
        self.isReportingEnabled = UserDefaults.standard.object(forKey: "isReportingEnabled") as? Bool ?? true
        self.musicReportingEnabled = UserDefaults.standard.object(forKey: "musicReportingEnabled") as? Bool ?? true
        self.systemReportingEnabled = UserDefaults.standard.object(forKey: "systemReportingEnabled") as? Bool ?? true
        self.activityReportingEnabled = UserDefaults.standard.object(forKey: "activityReportingEnabled") as? Bool ?? true
        
        // Statistics authorization
        self.musicStatsAuthorized = UserDefaults.standard.object(forKey: "musicStatsAuthorized") as? Bool ?? false
        
        // App lists
        self.musicAppWhitelist = UserDefaults.standard.stringArray(forKey: "musicAppWhitelist") ?? [
            "com.apple.Music",
            "com.spotify.client",
            "com.netease.163music",
            "com.tencent.QQMusicMac"
        ]
        
        self.activityAppBlacklist = UserDefaults.standard.stringArray(forKey: "activityAppBlacklist") ?? [
            "com.apple.Safari",
            "com.google.Chrome",
            "com.mozilla.firefox",
            "com.microsoft.Edge",
            "com.operasoftware.Opera",
            "com.brave.Browser"
        ]
        
        // Activity rules
        if let data = UserDefaults.standard.data(forKey: "activityRules"),
           let rules = try? JSONDecoder().decode([ActivityRule].self, from: data) {
            self.activityRules = rules
        } else {
            self.activityRules = ActivityRule.defaultRules
        }
        
        // Report interval (seconds)
        self.reportInterval = UserDefaults.standard.object(forKey: "reportInterval") as? TimeInterval ?? 5.0
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
            "activityRules", "reportInterval"
        ]
        
        keys.forEach { defaults.removeObject(forKey: $0) }
        
        // Reinitialize
        let newConfig = AppConfiguration()
        self.secretKey = newConfig.secretKey
        self.endpointURL = newConfig.endpointURL
        self.isReportingEnabled = newConfig.isReportingEnabled
        self.musicReportingEnabled = newConfig.musicReportingEnabled
        self.systemReportingEnabled = newConfig.systemReportingEnabled
        self.activityReportingEnabled = newConfig.activityReportingEnabled
        self.musicStatsAuthorized = newConfig.musicStatsAuthorized
        self.musicAppWhitelist = newConfig.musicAppWhitelist
        self.activityAppBlacklist = newConfig.activityAppBlacklist
        self.activityRules = newConfig.activityRules
        self.reportInterval = newConfig.reportInterval
    }
}

