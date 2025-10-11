//
//  AppConfiguration.swift
//  share-my-status-client
//


import Foundation
import SwiftUI
import Combine
import AppKit

// Exportable Configuration

/// Exportable configuration structure for JSON serialization
struct ExportableConfiguration: Codable {
    var secretKey: String?  // Optional to allow excluding sensitive data
    var endpointURL: String
    var musicReportingEnabled: Bool
    var systemReportingEnabled: Bool
    var activityReportingEnabled: Bool
    var musicStatsAuthorized: Bool
    var musicAppWhitelist: [String]
    var activityGroups: [ActivityGroup]
    var systemPollingInterval: TimeInterval
    var activityPollingInterval: TimeInterval
    
    var exportDate: String = ISO8601DateFormatter().string(from: Date())
    var version: String = "1.0"
}

// Application Configuration

@MainActor
class AppConfiguration: ObservableObject {
    // Network Configuration
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
    
    // Feature Toggles
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
    
    // Statistics Authorization
    @Published var musicStatsAuthorized: Bool {
        didSet {
            UserDefaults.standard.set(musicStatsAuthorized, forKey: "musicStatsAuthorized")
        }
    }
    
    // App Lists
    @Published var musicAppWhitelist: [String] {
        didSet {
            UserDefaults.standard.set(musicAppWhitelist, forKey: "musicAppWhitelist")
        }
    }
    
    @Published var activityGroups: [ActivityGroup] {
        didSet {
            if let encoded = try? JSONEncoder().encode(activityGroups) {
                UserDefaults.standard.set(encoded, forKey: "activityGroups")
            }
        }
    }
    
    // Polling Interval Settings
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
    
    // Initialization
    init() {
        // Network configuration
        self.secretKey = UserDefaults.standard.string(forKey: "secretKey") ?? DefaultSettings.secretKey
        self.endpointURL = UserDefaults.standard.string(forKey: "endpointURL") ?? DefaultSettings.endpointURL
        
        // Feature toggles
        self.musicReportingEnabled = UserDefaults.standard.object(forKey: "musicReportingEnabled") as? Bool ?? DefaultSettings.musicReportingEnabled
        self.systemReportingEnabled = UserDefaults.standard.object(forKey: "systemReportingEnabled") as? Bool ?? DefaultSettings.systemReportingEnabled
        self.activityReportingEnabled = UserDefaults.standard.object(forKey: "activityReportingEnabled") as? Bool ?? DefaultSettings.activityReportingEnabled
        
        // Statistics authorization
        self.musicStatsAuthorized = UserDefaults.standard.object(forKey: "musicStatsAuthorized") as? Bool ?? DefaultSettings.musicStatsAuthorized
        
        // App lists
        self.musicAppWhitelist = UserDefaults.standard.stringArray(forKey: "musicAppWhitelist") ?? DefaultSettings.musicAppWhitelist
        
        // Activity groups
        if let data = UserDefaults.standard.data(forKey: "activityGroups"),
           let groups = try? JSONDecoder().decode([ActivityGroup].self, from: data) {
            self.activityGroups = groups
        } else {
            self.activityGroups = DefaultSettings.activityGroups
        }
        
        // Polling intervals for each service (seconds)
        self.systemPollingInterval = UserDefaults.standard.object(forKey: "systemPollingInterval") as? TimeInterval ?? DefaultSettings.systemPollingInterval
        self.activityPollingInterval = UserDefaults.standard.object(forKey: "activityPollingInterval") as? TimeInterval ?? DefaultSettings.activityPollingInterval
    }
    
    // Convenience Methods
    func isValidConfiguration() -> Bool {
        return !secretKey.isEmpty && !endpointURL.isEmpty && URL(string: endpointURL) != nil
    }
    
    func resetToDefaults() {
        let defaults = UserDefaults.standard
        let keys = [
            "secretKey", "endpointURL",
            "musicReportingEnabled", "systemReportingEnabled", "activityReportingEnabled",
            "musicStatsAuthorized", "musicAppWhitelist",
            "activityGroups",
            "systemPollingInterval", "activityPollingInterval"
        ]
        
        keys.forEach { defaults.removeObject(forKey: $0) }
        
        // Reset to default values
        self.secretKey = DefaultSettings.secretKey
        self.endpointURL = DefaultSettings.endpointURL
        self.musicReportingEnabled = DefaultSettings.musicReportingEnabled
        self.systemReportingEnabled = DefaultSettings.systemReportingEnabled
        self.activityReportingEnabled = DefaultSettings.activityReportingEnabled
        self.musicStatsAuthorized = DefaultSettings.musicStatsAuthorized
        self.musicAppWhitelist = DefaultSettings.musicAppWhitelist
        self.activityGroups = DefaultSettings.activityGroups
        self.systemPollingInterval = DefaultSettings.systemPollingInterval
        self.activityPollingInterval = DefaultSettings.activityPollingInterval
    }
    
    // Import/Export
    
    /// Export configuration to JSON string
    /// - Parameter includeSecretKey: Whether to include the secret key in export
    /// - Returns: JSON string representation of configuration, or nil if encoding fails
    func exportToJSON(includeSecretKey: Bool = false) -> String? {
        let config = ExportableConfiguration(
            secretKey: includeSecretKey ? secretKey : nil,
            endpointURL: endpointURL,
            musicReportingEnabled: musicReportingEnabled,
            systemReportingEnabled: systemReportingEnabled,
            activityReportingEnabled: activityReportingEnabled,
            musicStatsAuthorized: musicStatsAuthorized,
            musicAppWhitelist: musicAppWhitelist,
            activityGroups: activityGroups,
            systemPollingInterval: systemPollingInterval,
            activityPollingInterval: activityPollingInterval
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let data = try? encoder.encode(config),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return jsonString
    }
    
    /// Export configuration to clipboard
    /// - Parameter includeSecretKey: Whether to include the secret key in export
    /// - Returns: True if export succeeded, false otherwise
    @discardableResult
    func exportToClipboard(includeSecretKey: Bool = false) -> Bool {
        guard let jsonString = exportToJSON(includeSecretKey: includeSecretKey) else {
            return false
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(jsonString, forType: .string)
        
        return true
    }
    
    /// Import configuration from JSON string
    /// - Parameter jsonString: JSON string containing configuration
    /// - Returns: Error message if import failed, nil if succeeded
    func importFromJSON(_ jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8) else {
            return "无效的文本格式"
        }
        
        let decoder = JSONDecoder()
        
        guard let config = try? decoder.decode(ExportableConfiguration.self, from: data) else {
            return "JSON 格式错误，请检查配置内容"
        }
        
        // Import all settings
        if let secretKey = config.secretKey, !secretKey.isEmpty {
            self.secretKey = secretKey
        }
        self.endpointURL = config.endpointURL
        self.musicReportingEnabled = config.musicReportingEnabled
        self.systemReportingEnabled = config.systemReportingEnabled
        self.activityReportingEnabled = config.activityReportingEnabled
        self.musicStatsAuthorized = config.musicStatsAuthorized
        self.musicAppWhitelist = config.musicAppWhitelist
        self.activityGroups = config.activityGroups
        self.systemPollingInterval = config.systemPollingInterval
        self.activityPollingInterval = config.activityPollingInterval
        
        return nil
    }
    
    /// Import configuration from clipboard
    /// - Returns: Error message if import failed, nil if succeeded
    func importFromClipboard() -> String? {
        let pasteboard = NSPasteboard.general
        
        guard let jsonString = pasteboard.string(forType: .string) else {
            return "剪贴板中没有文本内容"
        }
        
        return importFromJSON(jsonString)
    }
    
    /// Export configuration to file
    /// - Parameters:
    ///   - url: File URL to save to
    ///   - includeSecretKey: Whether to include the secret key in export
    /// - Returns: Error message if export failed, nil if succeeded
    func exportToFile(url: URL, includeSecretKey: Bool = false) -> String? {
        guard let jsonString = exportToJSON(includeSecretKey: includeSecretKey) else {
            return "配置序列化失败"
        }
        
        do {
            try jsonString.write(to: url, atomically: true, encoding: .utf8)
            return nil
        } catch {
            return "文件写入失败: \(error.localizedDescription)"
        }
    }
    
    /// Import configuration from file
    /// - Parameter url: File URL to read from
    /// - Returns: Error message if import failed, nil if succeeded
    func importFromFile(url: URL) -> String? {
        do {
            let jsonString = try String(contentsOf: url, encoding: .utf8)
            return importFromJSON(jsonString)
        } catch {
            return "文件读取失败: \(error.localizedDescription)"
        }
    }
    
    /// Validate JSON configuration format
    /// - Parameter jsonString: JSON string to validate
    /// - Returns: (isValid, errorMessage) tuple
    func validateConfigurationJSON(_ jsonString: String) -> (isValid: Bool, errorMessage: String?) {
        guard let data = jsonString.data(using: .utf8) else {
            return (false, "无效的文本格式")
        }
        
        let decoder = JSONDecoder()
        
        do {
            let config = try decoder.decode(ExportableConfiguration.self, from: data)
            
            // Validate required fields
            if config.endpointURL.isEmpty {
                return (false, "服务器地址不能为空")
            }
            
            if URL(string: config.endpointURL) == nil {
                return (false, "服务器地址格式无效")
            }
            
            // Validate intervals
            if config.systemPollingInterval < 1 || config.systemPollingInterval > 300 {
                return (false, "系统轮询间隔必须在 1-300 秒之间")
            }
            
            if config.activityPollingInterval < 1 || config.activityPollingInterval > 60 {
                return (false, "活动轮询间隔必须在 1-60 秒之间")
            }
            
            return (true, nil)
            
        } catch {
            return (false, "JSON 格式错误: \(error.localizedDescription)")
        }
    }
}

