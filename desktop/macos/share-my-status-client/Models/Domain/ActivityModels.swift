//
//  ActivityModels.swift
//  share-my-status-client
//


import Foundation

// Domain Activity Models

/// Activity snapshot from activity detection
struct ActivitySnapshot {
    let activeApplication: String
    let bundleIdentifier: String?
    let windowTitle: String?
    let idleTimeSeconds: TimeInterval
    let activityTag: String
    let timestamp: Date
    
    /// Convert to API ActivityInfo model
    func toActivityInfo() -> ActivityInfo {
        // Convert timestamp to milliseconds
        let timestampMs = Int64(timestamp.timeIntervalSince1970 * 1000)
        return ActivityInfo(
            label: activityTag,
            ts: timestampMs
        )
    }
}

/// Activity group for organizing applications by activity type
struct ActivityGroup: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var bundleIds: [String]
    var isEnabled: Bool
    
    enum CodingKeys: String, CodingKey {
        case name, bundleIds, isEnabled
    }
    
    init(id: UUID = UUID(), name: String, bundleIds: [String] = [], isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.bundleIds = bundleIds
        self.isEnabled = isEnabled
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.bundleIds = try container.decode([String].self, forKey: .bundleIds)
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(bundleIds, forKey: .bundleIds)
        try container.encode(isEnabled, forKey: .isEnabled)
    }
    
    /// Default activity groups (centralized in DefaultSettings)
    static var defaultGroups: [ActivityGroup] {
        return DefaultSettings.activityGroups
    }
}

// Formatting Extensions

extension ActivitySnapshot {
    var isIdle: Bool {
        return idleTimeSeconds > DefaultSettings.idleTimeThreshold
    }
    
    var formattedIdleTime: String {
        let minutes = Int(idleTimeSeconds / 60)
        let seconds = Int(idleTimeSeconds.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
    
    var displayTitle: String {
        if let windowTitle = windowTitle, !windowTitle.isEmpty {
            return "\(activeApplication) - \(windowTitle)"
        } else {
            return activeApplication
        }
    }
}

