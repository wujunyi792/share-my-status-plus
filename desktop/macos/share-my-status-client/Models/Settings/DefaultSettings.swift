//
//  DefaultSettings.swift
//  share-my-status-client
//
//

import Foundation

/// Application default settings constants
/// All default values are centralized here for consistency
enum DefaultSettings {
    
    // Network Configuration
    
    /// Default API endpoint URL
    static let endpointURL = "https://api.example.com/v1/state/report"
    
    /// Default secret key (empty, user must configure)
    static let secretKey = ""
    
    // Feature Toggles
    
    /// Default reporting enabled state
    static let isReportingEnabled = true
    
    /// Default music reporting enabled state
    static let musicReportingEnabled = true
    
    /// Default system reporting enabled state
    static let systemReportingEnabled = true
    
    /// Default activity reporting enabled state
    static let activityReportingEnabled = true
    
    // Statistics Authorization
    
    /// Default music statistics authorization state
    static let musicStatsAuthorized = false
    
    // App Lists
    
    /// Default music application whitelist
    static let musicAppWhitelist = [
        "com.apple.Music",
        "com.spotify.client",
        "com.netease.163music",
        "com.tencent.QQMusicMac",
        "com.soda.music"
    ]
    
    // Polling Intervals (seconds)
    
    /// Default system monitoring polling interval
    static let systemPollingInterval: TimeInterval = 10.0
    
    /// Default activity detection polling interval
    static let activityPollingInterval: TimeInterval = 5.0
    
    // Polling Interval Ranges
    
    /// System polling interval range (min...max)
    static let systemPollingIntervalRange: ClosedRange<TimeInterval> = 5...60
    
    /// System polling interval step
    static let systemPollingIntervalStep: TimeInterval = 5
    
    /// Activity polling interval range (min...max)
    static let activityPollingIntervalRange: ClosedRange<TimeInterval> = 1...30
    
    /// Activity polling interval step
    static let activityPollingIntervalStep: TimeInterval = 1
    
    // Activity Detection
    
    /// Default idle time threshold (seconds)
    static let idleTimeThreshold: TimeInterval = 300 // 5 minutes
    
    /// Default activity groups
    static let activityGroups = [
        ActivityGroup(name: "在工作", bundleIds: [
            "com.electron.lark",
            "com.tencent.xinWeChat",
            "com.microsoft.teams",
            "com.slack.Slack"
        ], isEnabled: true),
        ActivityGroup(name: "在写代码", bundleIds: [
            "com.apple.dt.Xcode",
            "com.microsoft.VSCode",
            "com.jetbrains.intellij",
            "com.jetbrains.pycharm",
            "com.jetbrains.goland",
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
}

