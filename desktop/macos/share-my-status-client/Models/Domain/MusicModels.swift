//
//  MusicModels.swift
//  share-my-status-client
//


import Foundation

// Domain Music Models

/// Music snapshot from MediaRemote
struct MusicSnapshot {
    let title: String
    let artist: String
    let album: String
    let isPlaying: Bool
    let bundleIdentifier: String?
    let artworkData: Data?
    let timestamp: Date
    
    /// Convert to API MusicInfo model
    func toMusicInfo(coverHash: String? = nil) -> MusicInfo {
        // Convert timestamp to milliseconds
        let timestampMs = Int64(timestamp.timeIntervalSince1970 * 1000)
        return MusicInfo(
            title: title,
            artist: artist,
            album: album,
            coverHash: coverHash,
            ts: timestampMs
        )
    }
}

/// MediaRemote player info (from MediaRemote adapter output)
struct MediaPlayerInfo: Codable {
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
}

extension MediaPlayerInfo {
    /// Convert MediaRemote output to MusicSnapshot
    func toMusicSnapshot() -> MusicSnapshot? {
        guard let title = title, !title.isEmpty,
              let artist = artist, !artist.isEmpty else {
            return nil
        }
        
        var artwork: Data? = nil
        if let artworkBase64 = artworkData {
            artwork = Data(base64Encoded: artworkBase64)
        }
        
        return MusicSnapshot(
            title: title,
            artist: artist,
            album: album ?? "Unknown Album",
            isPlaying: playing ?? false,
            bundleIdentifier: bundleIdentifier,
            artworkData: artwork,
            timestamp: Date()
        )
    }
}

