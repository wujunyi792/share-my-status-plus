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
    
    /// Default music reporting enabled state
    static let musicReportingEnabled = true
    
    /// Default system reporting enabled state
    static let systemReportingEnabled = true
    
    /// Default activity reporting enabled state
    static let activityReportingEnabled = true
    
    // Statistics Authorization
    
    
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
    static let systemPollingIntervalRange: ClosedRange<TimeInterval> = 5...300
    
    /// System polling interval step
    static let systemPollingIntervalStep: TimeInterval = 5
    
    /// Activity polling interval range (min...max)
    static let activityPollingIntervalRange: ClosedRange<TimeInterval> = 5...300
    
    /// Activity polling interval step
    static let activityPollingIntervalStep: TimeInterval = 5
    

     // Activity Detection
     
     /// Default idle time threshold (seconds)
     static let idleTimeThreshold: TimeInterval = 300 // 5 minutes
    
    /// Default activity groups
    static let activityGroups = [
        ActivityGroup(name: "在工作&研究", bundleIds: ["com.apple.iWork.Pages", "com.apple.iWork.Numbers", "com.apple.iWork.Keynote", "com.microsoft.Word", "com.microsoft.Excel", "com.microsoft.Powerpoint", "com.microsoft.onenote.mac", "com.microsoft.Outlook", "com.microsoft.teams", "com.electron.lark", "com.volcengine.corplink", "com.raycast.macos", "cn.trae.app", "com.trae.app", "com.microsoft.OneDrive"], isEnabled: true),
        ActivityGroup(name: "在搞研发", bundleIds: ["com.microsoft.VSCode", "com.sublimetext.3", "com.apple.dt.Xcode", "com.SweetScape.010Editor", "me.qii404.another-redis-desktop-manager", "cn.apifox.app", "com.todesktop.230313mzl4w4u92", "com.jetbrains.goland", "com.jetbrains.toolbox", "com.mongodb.compass", "com.electron.ollama", "io.podmandesktop.PodmanDesktop", "com.postmanlabs.mac"], isEnabled: true),
        ActivityGroup(name: "在设计", bundleIds: ["com.bohemiancoding.sketch3", "com.figma.Desktop", "com.adobe.Photoshop"], isEnabled: true),
        ActivityGroup(name: "在开会", bundleIds: ["us.zoom.xos", "com.tinyspeck.slackmacgap"], isEnabled: true),
        ActivityGroup(name: "在浏览", bundleIds: ["com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox", "com.brave.Browser", "com.operasoftware.Opera", "company.thebrowser.Browser", "com.microsoft.edgemac", "com.vivaldi.Vivaldi"], isEnabled: true),
        ActivityGroup(name: "在终端", bundleIds: ["com.apple.Terminal", "com.googlecode.iterm2", "com.googlecode.iterm2.iTermAI", "com.termius-dmg.mac"], isEnabled: true),
        ActivityGroup(name: "在娱乐", bundleIds:["com.bytedance.douyin.desktop", "com.soda.music", "com.xingin.discover", "com.meituan.imovie", "com.netease.163music", "com.tencent.QQMusicMac", "com.spotify.client", "com.apple.Music", "com.aspiro.tidal"], isEnabled: true),
        ActivityGroup(name: "在社交", bundleIds: ["com.tencent.qq", "ru.keepcoder.Telegram", "com.hnc.Discord", "net.whatsapp.WhatsApp", "com.tencent.xinwei.mac"], isEnabled: true),
    ]
}

