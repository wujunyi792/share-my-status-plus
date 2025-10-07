//
//  MediaRemoteService.swift
//  share-my-status-client
//
//  Created by Refactor on 2025-01-07.
//

import Foundation
import AppKit

/// Actor-based MediaRemote service for thread-safe music info extraction
actor MediaRemoteService: EventDrivenMonitoringService {
    // MARK: - EventDrivenMonitoringService Conformance
    typealias EventData = MusicSnapshot
    
    let monitoringType: MonitoringType = .eventDriven
    
    func isActive() -> Bool {
        return isStreaming
    }
    
    func start() async throws {
        guard let callback = self.eventCallback else {
            throw MediaRemoteError.executionFailed("No callback registered")
        }
        try await startStreaming(onUpdate: callback)
    }
    
    func stop() async {
        stopStreaming()
    }
    
    func registerCallback(_ callback: @escaping (MusicSnapshot?) -> Void) async {
        self.eventCallback = callback
    }
    
    // MARK: - Properties
    private let config: MediaRemoteAdapterConfig
    private let logger = AppLogger.media
    private var whitelistedBundleIds: [String] = []
    
    private var streamProcess: Process?
    private var currentMusic: MusicSnapshot?
    private var isStreaming = false
    private var eventCallback: ((MusicSnapshot?) -> Void)?
    
    // Buffer for incomplete JSON lines
    private var lineBuffer = ""
    
    // MARK: - Initialization
    init(config: MediaRemoteAdapterConfig = .default) {
        self.config = config
    }
    
    deinit {
        Task { [streamProcess] in
            streamProcess?.terminate()
        }
    }
    
    // MARK: - Configuration
    func updateWhitelist(_ bundleIds: [String]) {
        self.whitelistedBundleIds = bundleIds
    }
    
    // MARK: - Get Music Info (One-time)
    func getMusicInfo() async throws -> MusicSnapshot? {
        logger.info("Getting current music info...")
        
        guard config.validate() else {
            logger.error("MediaRemote adapter validation failed")
            logger.error("Script path: \(config.scriptPath)")
            logger.error("Framework path: \(config.frameworkPath)")
            throw MediaRemoteError.adapterNotFound
        }
        
        // Arguments: FRAMEWORK_PATH FUNCTION
        let arguments = [config.frameworkPath, MediaRemoteCommand.get.commandString]
        
        do {
            let (output, exitCode) = try await Process.runAsync(
                launchPath: config.scriptPath,  // Run the Perl script directly (with shebang)
                arguments: arguments,
                timeout: 10
            )
            
            guard exitCode == 0 else {
                if let errorMsg = String(data: output, encoding: .utf8) {
                    logger.error("MediaRemote adapter error: \(errorMsg)")
                }
                logger.error("MediaRemote adapter exit code: \(exitCode)")
                throw MediaRemoteError.executionFailed("Exit code: \(exitCode)")
            }
            
            // Parse JSON output
            logger.info("MediaRemote adapter output length: \(output.count) bytes")
            let decoder = JSONDecoder()
            guard let mediaInfo = try? decoder.decode(MediaRemoteOutput.self, from: output) else {
                if let outputStr = String(data: output, encoding: .utf8) {
                    logger.error("Failed to decode MediaRemote output: \(outputStr.prefix(200))")
                } else {
                    logger.error("Failed to decode MediaRemote output (invalid UTF-8)")
                }
                throw MediaRemoteError.decodingFailed
            }
            
            logger.info("MediaRemote output decoded - title: \(mediaInfo.title ?? "nil"), artist: \(mediaInfo.artist ?? "nil"), playing: \(mediaInfo.playing ?? false)")
            
            guard mediaInfo.isValid else {
                logger.info("No valid music playing (missing title or artist)")
                return nil
            }
            
            // Check whitelist
            if let bundleId = mediaInfo.bundleIdentifier,
               !whitelistedBundleIds.isEmpty,
               !whitelistedBundleIds.contains(bundleId) {
                logger.info("Music from \(bundleId) is not in whitelist (whitelist: \(whitelistedBundleIds))")
                return nil
            }
            
            // Convert to MusicSnapshot
            guard let snapshot = convertToSnapshot(mediaInfo) else {
                return nil
            }
            
            logger.info("Got music: \(snapshot.artist) - \(snapshot.title)")
            return snapshot
            
        } catch let error as MediaRemoteError {
            throw error
        } catch {
            logger.error("Unexpected error: \(error.localizedDescription)")
            throw MediaRemoteError.executionFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Stream Music Info (Real-time)
    func startStreaming(onUpdate: @escaping (MusicSnapshot?) -> Void) async throws {
        guard !isStreaming else {
            logger.warning("Already streaming")
            return
        }
        
        guard config.validate() else {
            logger.error("MediaRemote adapter validation failed")
            logger.error("Script path: \(config.scriptPath)")
            logger.error("Framework path: \(config.frameworkPath)")
            throw MediaRemoteError.adapterNotFound
        }
        
        logger.info("Starting music streaming with whitelist: \(whitelistedBundleIds)")
        logger.info("Script path: \(config.scriptPath)")
        logger.info("Framework path: \(config.frameworkPath)")
        isStreaming = true
        
        // Arguments: FRAMEWORK_PATH FUNCTION
        let arguments = [config.frameworkPath, MediaRemoteCommand.stream.commandString]
        logger.info("Launching MediaRemote stream: \(config.scriptPath) with arguments: \(arguments)")
        
        let process = Process()
        process.launchPath = config.scriptPath  // Run the Perl script directly (with shebang)
        process.arguments = arguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Handle stderr output
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { return }
            
            if let errorMsg = String(data: data, encoding: .utf8), !errorMsg.isEmpty {
                Task { [weak self] in
                    await self?.logger.error("MediaRemote stderr: \(errorMsg)")
                }
            }
        }
        
        self.streamProcess = process
        
        // Handle output line by line
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { return }
            
            // Convert data to string and append to buffer
            if let chunk = String(data: data, encoding: .utf8) {
                Task { [weak self] in
                    await self?.processStreamChunk(chunk, onUpdate: onUpdate)
                }
            }
        }
        
        process.terminationHandler = { [weak self] process in
            Task { [weak self] in
                await self?.handleStreamTermination(exitCode: process.terminationStatus)
            }
        }
        
        try process.run()
        logger.info("Music streaming started")
    }
    
    func stopStreaming() {
        guard isStreaming else { return }
        
        logger.info("Stopping music streaming...")
        streamProcess?.terminate()
        streamProcess = nil
        isStreaming = false
        currentMusic = nil
        lineBuffer = ""  // Clear buffer
    }
    
    // MARK: - Current State
    func getCurrentMusic() -> MusicSnapshot? {
        return currentMusic
    }
    
    func getIsStreaming() -> Bool {
        return isStreaming
    }
    
    // MARK: - Test Adapter
    func testAdapter() async throws -> Bool {
        guard config.validate() else {
            throw MediaRemoteError.adapterNotFound
        }
        
        // Test using 'get' command - if it returns without error, adapter works
        do {
            _ = try await getMusicInfo()
            return true
        } catch MediaRemoteError.noMusicPlaying {
            // No music playing is OK for the test
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Private Helpers
    
    /// Process incoming stream chunk, handling multiple or incomplete JSON lines
    private func processStreamChunk(_ chunk: String, onUpdate: @escaping (MusicSnapshot?) -> Void) {
        // Append chunk to buffer
        lineBuffer.append(chunk)
        
        // Split buffer by newlines
        let lines = lineBuffer.components(separatedBy: .newlines)
        
        // Keep the last incomplete line in buffer
        lineBuffer = lines.last ?? ""
        
        // Process all complete lines (all except the last)
        for line in lines.dropLast() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedLine.isEmpty {
                processStreamLine(trimmedLine, onUpdate: onUpdate)
            }
        }
    }
    
    /// Process a single complete JSON line
    private func processStreamLine(_ line: String, onUpdate: @escaping (MusicSnapshot?) -> Void) {
        // Log raw JSON line for debugging (truncated to avoid spam)
        if line.count > 200 {
            logger.info("Raw JSON line: \(line.prefix(200))...")
        } else {
            logger.info("Raw JSON line: \(line)")
        }
        
        // Each line should be a JSON object
        guard let data = line.data(using: .utf8) else { 
            logger.warning("Failed to convert stream line to UTF-8")
            return 
        }
        
        // Stream output has nested structure: {type, diff, payload: {...}}
        let decoder = JSONDecoder()
        guard let streamOutput = try? decoder.decode(MediaRemoteStreamOutput.self, from: data) else {
            logger.warning("Failed to decode stream line: \(line.prefix(200))")
            return
        }
        
        // Convert to flat structure
        let mediaInfo = streamOutput.toMediaRemoteOutput()
        
        logger.info("Stream update - type: \(streamOutput.type), diff: \(streamOutput.diff), title: \(mediaInfo.title ?? "nil"), artist: \(mediaInfo.artist ?? "nil"), bundle: \(mediaInfo.bundleIdentifier ?? "nil"), playing: \(mediaInfo.playing ?? false)")
        
        // Handle differential updates
        if streamOutput.diff {
            // This is a diff update - only changed fields are present
            // If we don't have title/artist, it means they haven't changed
            if !mediaInfo.isValid {
                logger.info("Diff update without title/artist - merging with current music")
                
                // Merge artwork data with current music if present
                if let current = currentMusic, let artworkBase64 = mediaInfo.artworkData {
                    logger.info("Updating artwork for current music (size: \(artworkBase64.count) chars)")
                    let artworkData = Data(base64Encoded: artworkBase64)
                    
                    // Create updated snapshot with new artwork
                    let updatedSnapshot = MusicSnapshot(
                        title: current.title,
                        artist: current.artist,
                        album: current.album,
                        isPlaying: current.isPlaying,
                        bundleIdentifier: current.bundleIdentifier,
                        artworkData: artworkData,
                        timestamp: Date()
                    )
                    
                    currentMusic = updatedSnapshot
                    onUpdate(updatedSnapshot)
                    logger.info("Artwork updated for: \(current.artist) - \(current.title)")
                } else {
                    logger.info("No current music or no artwork data in diff update")
                }
                return
            }
        }
        
        // Check if valid and in whitelist (full update or complete diff)
        if !mediaInfo.isValid {
            logger.info("Stream music invalid (missing title or artist)")
            currentMusic = nil
            onUpdate(nil)
            return
        }
        
        if let bundleId = mediaInfo.bundleIdentifier,
           !whitelistedBundleIds.isEmpty,
           !whitelistedBundleIds.contains(bundleId) {
            logger.info("Stream music from \(bundleId) not in whitelist")
            currentMusic = nil
            onUpdate(nil)
            return
        }
        
        // Convert to snapshot
        if let snapshot = convertToSnapshot(mediaInfo) {
            logger.info("Music snapshot created: \(snapshot.artist) - \(snapshot.title)")
            currentMusic = snapshot
            onUpdate(snapshot)
        } else {
            logger.warning("Failed to convert media info to snapshot")
            currentMusic = nil
            onUpdate(nil)
        }
    }
    
    private func handleStreamTermination(exitCode: Int32) {
        logger.info("MediaRemote stream terminated with code \(exitCode)")
        isStreaming = false
        streamProcess = nil
        currentMusic = nil
        lineBuffer = ""
        
        if exitCode != 0 {
            logger.error("MediaRemote stream terminated abnormally with code \(exitCode)")
        } else {
            logger.info("MediaRemote stream terminated normally")
        }
    }
    
    private func convertToSnapshot(_ mediaInfo: MediaRemoteOutput) -> MusicSnapshot? {
        guard let title = mediaInfo.title, !title.isEmpty,
              let artist = mediaInfo.artist, !artist.isEmpty else {
            return nil
        }
        
        var artwork: Data? = nil
        if let artworkBase64 = mediaInfo.artworkData {
            artwork = Data(base64Encoded: artworkBase64)
        }
        
        return MusicSnapshot(
            title: title,
            artist: artist,
            album: mediaInfo.album ?? "Unknown Album",
            isPlaying: mediaInfo.playing ?? false,
            bundleIdentifier: mediaInfo.bundleIdentifier,
            artworkData: artwork,
            timestamp: Date()
        )
    }
}

