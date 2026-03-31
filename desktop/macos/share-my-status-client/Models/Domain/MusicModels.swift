//
//  MusicModels.swift
//  share-my-status-client
//


import Foundation
import AppKit

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
    
    /// Lazily-created, cached NSImage from artworkData.
    /// Avoids re-decoding image bytes on every SwiftUI render cycle.
    var artworkImage: NSImage? {
        guard let data = artworkData else { return nil }
        return ArtworkImageCache.shared.image(for: data)
    }
    
    /// Convert to API MusicInfo model
    func toMusicInfo(coverHash: String? = nil) -> MusicInfo {
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

/// Thread-safe LRU-style cache for decoded artwork images.
/// Keyed by data byte count + prefix hash to avoid full-data hashing overhead.
final class ArtworkImageCache: @unchecked Sendable {
    static let shared = ArtworkImageCache()
    
    private let lock = NSLock()
    private var cache: [Int: (data: Data, image: NSImage)] = [:]
    private static let maxEntries = 5
    
    func image(for data: Data) -> NSImage? {
        let key = data.count ^ data.prefix(64).hashValue
        lock.lock()
        if let entry = cache[key], entry.data == data {
            lock.unlock()
            return entry.image
        }
        lock.unlock()
        
        guard let img = NSImage(data: data) else { return nil }
        
        lock.lock()
        if cache.count >= Self.maxEntries {
            cache.removeAll(keepingCapacity: true)
        }
        cache[key] = (data, img)
        lock.unlock()
        return img
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

