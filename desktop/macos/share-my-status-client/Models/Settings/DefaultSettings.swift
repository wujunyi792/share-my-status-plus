//
//  DefaultSettings.swift
//  share-my-status-client
//
//  Created by Refactor on 2025-01-07.
//  统一管理所有默认设置值
//

import Foundation

/// Application default settings constants
/// All default values are centralized here for consistency
enum DefaultSettings {
    
    // MARK: - Network Configuration
    
    /// Default API endpoint URL
    static let endpointURL = "https://api.example.com/v1/state/report"
    
    /// Default secret key (empty, user must configure)
    static let secretKey = ""
    
    // MARK: - Feature Toggles
    
    /// Default reporting enabled state
    static let isReportingEnabled = true
    
    /// Default music reporting enabled state
    static let musicReportingEnabled = true
    
    /// Default system reporting enabled state
    static let systemReportingEnabled = true
    
    /// Default activity reporting enabled state
    static let activityReportingEnabled = true
    
    // MARK: - Statistics Authorization
    
    /// Default music statistics authorization state
    static let musicStatsAuthorized = false
    
    // MARK: - App Lists
    
    /// Default music application whitelist
    static let musicAppWhitelist = [
        "com.apple.Music",
        "com.spotify.client",
        "com.netease.163music",
        "com.tencent.QQMusicMac"
    ]
    
    /// Default activity application blacklist
    static let activityAppBlacklist = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.mozilla.firefox",
        "com.microsoft.Edge",
        "com.operasoftware.Opera",
        "com.brave.Browser"
    ]
    
    // MARK: - Polling Intervals (seconds)
    
    /// Default report interval (deprecated, kept for backward compatibility)
    static let reportInterval: TimeInterval = 5.0
    
    /// Default system monitoring polling interval
    static let systemPollingInterval: TimeInterval = 10.0
    
    /// Default activity detection polling interval
    static let activityPollingInterval: TimeInterval = 5.0
    
    // MARK: - Polling Interval Ranges
    
    /// System polling interval range (min...max)
    static let systemPollingIntervalRange: ClosedRange<TimeInterval> = 5...60
    
    /// System polling interval step
    static let systemPollingIntervalStep: TimeInterval = 5
    
    /// Activity polling interval range (min...max)
    static let activityPollingIntervalRange: ClosedRange<TimeInterval> = 1...30
    
    /// Activity polling interval step
    static let activityPollingIntervalStep: TimeInterval = 1
    
    // MARK: - Activity Detection
    
    /// Default idle time threshold (seconds)
    static let idleTimeThreshold: TimeInterval = 300 // 5 minutes
    
    /// Default activity groups
    static let activityGroups = [
        ActivityGroup(name: "在工作", bundleIds: [
            "com.lark.lark",
            "com.tencent.xinWeChat",
            "com.microsoft.teams",
            "com.slack.Slack"
        ], isEnabled: true),
        ActivityGroup(name: "在写代码", bundleIds: [
            "com.apple.dt.Xcode",
            "com.microsoft.VSCode",
            "com.jetbrains.intellij",
            "com.jetbrains.pycharm",
            "com.github.atom",
            "com.sublimetext.3"
        ], isEnabled: true),
        ActivityGroup(name: "在设计", bundleIds: [
            "com.adobe.Photoshop",
            "com.bohemiancoding.sketch3",
            "com.figma.Desktop",
            "com.adobe.Illustrator",
            "com.adobe.AfterEffects"
        ], isEnabled: true),
        ActivityGroup(name: "在开会", bundleIds: [
            "us.zoom.xos",
            "com.microsoft.teams",
            "com.tencent.meeting",
            "com.skype.skype"
        ], isEnabled: true),
        ActivityGroup(name: "在浏览", bundleIds: [
            "com.apple.Safari",
            "com.google.Chrome",
            "org.mozilla.firefox",
            "com.microsoft.edgemac"
        ], isEnabled: false),
        ActivityGroup(name: "在终端", bundleIds: [
            "com.apple.Terminal",
            "com.googlecode.iterm2"
        ], isEnabled: true)
    ]
    
    /// Default activity rules (deprecated, use activityGroups instead)
    static let activityRules = [
        ActivityRule(pattern: "com.lark.lark", label: "在工作", isEnabled: true),
        ActivityRule(pattern: "com.apple.dt.Xcode", label: "在写代码", isEnabled: true),
        ActivityRule(pattern: "com.microsoft.VSCode", label: "在写代码", isEnabled: true),
        ActivityRule(pattern: "com.jetbrains.intellij", label: "在写代码", isEnabled: true),
        ActivityRule(pattern: "com.adobe.Photoshop", label: "在设计", isEnabled: true),
        ActivityRule(pattern: "com.bohemiancoding.sketch3", label: "在设计", isEnabled: true),
        ActivityRule(pattern: "com.figma.Desktop", label: "在设计", isEnabled: true),
        ActivityRule(pattern: "us.zoom.xos", label: "在开会", isEnabled: true),
        ActivityRule(pattern: "com.microsoft.teams", label: "在开会", isEnabled: true),
        ActivityRule(pattern: "com.tencent.meeting", label: "在开会", isEnabled: true),
        ActivityRule(pattern: "com.apple.Safari", label: "在浏览", isEnabled: false),
        ActivityRule(pattern: "com.google.Chrome", label: "在浏览", isEnabled: false),
        ActivityRule(pattern: "org.mozilla.firefox", label: "在浏览", isEnabled: false),
        ActivityRule(pattern: "com.apple.Terminal", label: "在终端", isEnabled: true),
        ActivityRule(pattern: "com.googlecode.iterm2", label: "在终端", isEnabled: true)
    ]
}

