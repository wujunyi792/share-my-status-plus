//
//  APIModels.swift
//  share-my-status-client
//


import Foundation

// Base Response (from common.thrift)

/// Base response structure for all API responses
struct BaseResponse: Codable {
    let code: Int32
    let message: String?
    let warnings: [String]?
}

// Common Domain Models

/// System information structure (from common.thrift)
struct SystemInfo: Codable {
    let batteryPct: Double?    // 0-1
    let charging: Bool?
    let cpuPct: Double?        // 0-1
    let memoryPct: Double?     // 0-1
    let ts: Int64              // millisecond timestamp (required in Thrift)
}

/// Music information structure (from common.thrift)
struct MusicInfo: Codable {
    let title: String?
    let artist: String?
    let album: String?
    let coverHash: String?
    let ts: Int64              // millisecond timestamp (required in Thrift)
}

/// Activity information structure (from common.thrift)
struct ActivityInfo: Codable {
    let label: String          // e.g., "在工作", "在写代码" (required)
    let ts: Int64              // millisecond timestamp (required in Thrift)
}

/// Report event structure (from common.thrift)
struct ReportEvent: Codable {
    let version: String
    let system: SystemInfo?
    let music: MusicInfo?
    let activity: ActivityInfo?
    let idempotencyKey: String?
    
    init(system: SystemInfo? = nil, 
         music: MusicInfo? = nil, 
         activity: ActivityInfo? = nil) {
        self.version = "1"
        self.system = system
        self.music = music
        self.activity = activity
        self.idempotencyKey = UUID().uuidString
    }
}

/// Status snapshot structure (from common.thrift)
struct StatusSnapshot: Codable {
    let system: SystemInfo?
    let music: MusicInfo?
    let activity: ActivityInfo?
    let lastUpdateTs: Int64
}

