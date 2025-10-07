//
//  SystemModels.swift
//  share-my-status-client
//
//  Created by Refactor on 2025-01-07.
//

import Foundation

// MARK: - Domain System Models

/// System snapshot from system monitoring
struct SystemSnapshot {
    let batteryLevel: Double?      // 0-1
    let isCharging: Bool?
    let cpuUsage: Double?          // 0-1
    let memoryUsage: Double?       // 0-1
    let timestamp: Date
    
    /// Convert to API SystemInfo model
    func toSystemInfo() -> SystemInfo {
        // Convert timestamp to milliseconds
        let timestampMs = Int64(timestamp.timeIntervalSince1970 * 1000)
        return SystemInfo(
            batteryPct: batteryLevel,
            charging: isCharging,
            cpuPct: cpuUsage,
            memoryPct: memoryUsage,
            ts: timestampMs
        )
    }
}

// MARK: - Formatting Extensions

extension SystemSnapshot {
    var batteryPercentage: Int? {
        guard let level = batteryLevel else { return nil }
        return Int(level * 100)
    }
    
    var cpuPercentage: Int? {
        guard let usage = cpuUsage else { return nil }
        return Int(usage * 100)
    }
    
    var memoryPercentage: Int? {
        guard let usage = memoryUsage else { return nil }
        return Int(usage * 100)
    }
    
    var formattedBattery: String {
        guard let percentage = batteryPercentage else { return "Unknown" }
        let chargingStatus = isCharging == true ? " (Charging)" : ""
        return "\(percentage)%\(chargingStatus)"
    }
    
    var formattedCPU: String {
        guard let percentage = cpuPercentage else { return "Unknown" }
        return "\(percentage)%"
    }
    
    var formattedMemory: String {
        guard let percentage = memoryPercentage else { return "Unknown" }
        return "\(percentage)%"
    }
}

