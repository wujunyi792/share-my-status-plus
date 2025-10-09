//
//  AppVersionUtility.swift
//  share-my-status-client
//

import Foundation

/// Utility for retrieving app version information
struct AppVersionUtility {
    
    /// Get the app version string (CFBundleShortVersionString)
    static var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知版本"
    }
    
    /// Get the build number (CFBundleVersion)
    static var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "未知构建"
    }
    
    /// Get the app name (CFBundleDisplayName or CFBundleName)
    static var appName: String {
        return Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ??
               Bundle.main.infoDictionary?["CFBundleName"] as? String ??
               "Share My Status"
    }
    
    /// Get the bundle identifier
    static var bundleIdentifier: String {
        return Bundle.main.bundleIdentifier ?? "com.share-my-status.client"
    }
    
    /// Get formatted version string for display
    static var formattedVersion: String {
        let version = appVersion
        let build = buildNumber
        
        if version != "未知版本" && build != "未知构建" && version != build {
            return "\(version) (\(build))"
        } else if version != "未知版本" {
            return version
        } else {
            return "未知版本"
        }
    }
    
    /// Get full app info string
    static var fullAppInfo: String {
        return "\(appName) \(formattedVersion)"
    }
}