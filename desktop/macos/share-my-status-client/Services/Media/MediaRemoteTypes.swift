//
//  MediaRemoteTypes.swift
//  share-my-status-client
//
//  Created by Refactor on 2025-01-07.
//

import Foundation

// MARK: - MediaRemote Adapter Command Types

/// MediaRemote adapter command
enum MediaRemoteCommand {
    case get        // Get current now playing info once
    case stream     // Stream real-time updates
    case test       // Test if adapter is functional
    
    var commandString: String {
        switch self {
        case .get: return "get"
        case .stream: return "stream"
        case .test: return "test"
        }
    }
}

/// MediaRemote adapter output (from JSON) - used by "get" command
struct MediaRemoteOutput: Codable {
    let artist: String?
    let title: String?
    let album: String?
    let duration: Double?
    let elapsedTime: Double?
    let playing: Bool?
    let bundleIdentifier: String?
    let playbackRate: Double?
    let artworkMimeType: String?
    let artworkData: String?  // base64 encoded
    
    /// Check if this is valid music data
    var isValid: Bool {
        guard let title = title, !title.isEmpty,
              let artist = artist, !artist.isEmpty else {
            return false
        }
        return true
    }
}

/// MediaRemote stream output (from JSON) - used by "stream" command
/// Stream returns nested structure: {"type":"data","diff":false,"payload":{...}}
struct MediaRemoteStreamOutput: Codable {
    let type: String
    let diff: Bool
    let payload: MediaRemoteOutput
    
    /// Convert to flat MediaRemoteOutput
    func toMediaRemoteOutput() -> MediaRemoteOutput {
        return payload
    }
}

// MARK: - MediaRemote Adapter Configuration

struct MediaRemoteAdapterConfig {
    let perlPath: String
    let scriptPath: String
    let frameworkPath: String
    let testClientPath: String?
    
    /// Default configuration using system perl and bundled resources
    static var `default`: MediaRemoteAdapterConfig {
        let bundle = Bundle.main.bundlePath
        return MediaRemoteAdapterConfig(
            perlPath: "/usr/bin/perl",
            scriptPath: "\(bundle)/Contents/Resources/mediaremote-adapter.pl",
            frameworkPath: "\(bundle)/Contents/Frameworks/MediaRemoteAdapter.framework",
            testClientPath: nil  // Optional for now
        )
    }
    
    /// Verify all required files exist
    func validate() -> Bool {
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: perlPath) &&
               fileManager.fileExists(atPath: scriptPath) &&
               fileManager.fileExists(atPath: frameworkPath)
    }
}

// MARK: - MediaRemote Errors

enum MediaRemoteError: LocalizedError {
    case adapterNotFound
    case invalidConfiguration
    case executionFailed(String)
    case decodingFailed
    case noMusicPlaying
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .adapterNotFound:
            return "MediaRemote adapter files not found"
        case .invalidConfiguration:
            return "MediaRemote adapter configuration is invalid"
        case .executionFailed(let message):
            return "MediaRemote adapter execution failed: \(message)"
        case .decodingFailed:
            return "Failed to decode MediaRemote output"
        case .noMusicPlaying:
            return "No music is currently playing"
        case .timeout:
            return "MediaRemote adapter timed out"
        }
    }
}

