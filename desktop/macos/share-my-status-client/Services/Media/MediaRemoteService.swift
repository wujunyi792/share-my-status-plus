//
//  MediaRemoteService.swift
//  share-my-status-client
//
//  Created by Refactor on 2025-01-07.
//

import Foundation
import AppKit

/// Actor-based MediaRemote service for thread-safe music info extraction
actor MediaRemoteService {
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
        logger.info("MediaRemoteService.stop() called")
        stopStreaming()
        logger.info("MediaRemoteService.stop() completed")
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
    
    // Store pipes to clean up handlers
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    
    // Serial queue for chunk processing to maintain order
    private var processingQueue: DispatchQueue?
    
    // Buffer for incomplete JSON lines
    private var lineBuffer = ""
    
    // State tracking for song change + artwork update sequence
    private enum SongChangeState {
        case idle                           // No pending changes
        case waitingForArtwork(MusicSnapshot)  // Song changed, waiting for artwork update
    }
    private var songChangeState: SongChangeState = .idle
    
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
            logger.warning("Already streaming - ignoring duplicate start request")
            return
        }
        
        // Stop any existing stream first
        if streamProcess != nil {
            logger.warning("Existing stream process found, stopping it first")
            stopStreaming()
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
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe
        
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
        
        // Generate unique ID for this stream session
        let streamID = UUID().uuidString.prefix(8)
        logger.info("Stream session ID: \(streamID)")
        
        // Create serial queue for this stream session to maintain chunk order
        let queue = DispatchQueue(label: "com.sharemystatus.mediaremote.stream.\(streamID)", qos: .userInitiated)
        self.processingQueue = queue
        
        // Handle output line by line
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { return }
            
            // Convert data to string
            guard let chunk = String(data: data, encoding: .utf8) else { return }
            
            // Process on serial queue to maintain chunk order
            // Use sync to ensure chunks are processed sequentially
            queue.async {
                // Create a semaphore to wait for async processing to complete
                let semaphore = DispatchSemaphore(value: 0)
                
                Task { [weak self] in
                    defer { semaphore.signal() }
                    await self?.logger.debug("[\(streamID)] Received chunk: \(chunk.count) bytes")
                    await self?.processStreamChunk(chunk, onUpdate: onUpdate)
                }
                
                semaphore.wait()
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
        guard isStreaming else { 
            logger.info("Not streaming, nothing to stop")
            return 
        }
        
        logger.info("Stopping music streaming...")
        
        // Clear pipe handlers FIRST to prevent further data processing
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        
        // Terminate process
        if let process = streamProcess {
            logger.info("Terminating stream process PID: \(process.processIdentifier)")
            process.terminate()
        }
        
        // Clean up
        songChangeState = .idle
        
        streamProcess = nil
        outputPipe = nil
        errorPipe = nil
        processingQueue = nil
        isStreaming = false
        currentMusic = nil
        lineBuffer = ""
        
        logger.info("Music streaming stopped")
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
    
    /// Process incoming stream chunk, handling multiple or incomplete JSON objects
    /// MediaRemote outputs Newline-Delimited JSON (NDJSON): one JSON per line
    private func processStreamChunk(_ chunk: String, onUpdate: @escaping (MusicSnapshot?) -> Void) {
        // Append chunk to buffer
        lineBuffer.append(chunk)
        logger.debug("Buffer size after append: \(lineBuffer.count) bytes")
        
        // Process all complete lines (ending with \n)
        // MediaRemote outputs compact JSON (no internal newlines), so \n is safe delimiter
        while let newlineRange = lineBuffer.range(of: "\n") {
            // Extract the complete line (without newline)
            let line = String(lineBuffer[..<newlineRange.lowerBound])
            
            // Remove this line from buffer (including the newline)
            lineBuffer.removeSubrange(..<newlineRange.upperBound)
            
            // Process non-empty lines
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedLine.isEmpty {
                logger.debug("Processing complete line: \(trimmedLine.count) chars")
                processStreamLine(trimmedLine, onUpdate: onUpdate)
            }
        }
        
        // Log if there's remaining incomplete data
        if !lineBuffer.isEmpty {
            logger.debug("Incomplete line in buffer: \(lineBuffer.count) bytes (waiting for newline)")
        }
        
        // Safety: prevent buffer overflow (10MB limit for large artwork)
        if lineBuffer.count > 10_000_000 {
            logger.error("Buffer exceeded 10MB! This indicates a problem. Clearing buffer.")
            logger.error("Buffer starts with: \(lineBuffer.prefix(100))")
            lineBuffer = ""
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
        
        logger.info("Stream update - type: \(streamOutput.type), diff: \(streamOutput.diff), title: \(mediaInfo.title ?? "nil"), artist: \(mediaInfo.artist ?? "nil"), playing: \(mediaInfo.playing ?? false)")
        
        // Handle differential updates
        if streamOutput.diff {
            // Diff update - only changed fields are present
            handleDiffUpdate(mediaInfo, onUpdate: onUpdate)
            return
        }
        
        // Full update (diff: false) - this is a new song or initial state
        handleFullUpdate(mediaInfo, onUpdate: onUpdate)
    }
    
    /// Handle full update (diff: false) - new song or initial state
    private func handleFullUpdate(_ mediaInfo: MediaRemoteOutput, onUpdate: @escaping (MusicSnapshot?) -> Void) {
        // Validate and check whitelist
        guard mediaInfo.isValid else {
            logger.info("Full update invalid (missing title or artist)")
            currentMusic = nil
            songChangeState = .idle
            onUpdate(nil)
            return
        }
        
        if let bundleId = mediaInfo.bundleIdentifier,
           !whitelistedBundleIds.isEmpty,
           !whitelistedBundleIds.contains(bundleId) {
            logger.info("Music from \(bundleId) not in whitelist")
            currentMusic = nil
            songChangeState = .idle
            onUpdate(nil)
            return
        }
        
        // Convert to snapshot
        guard let snapshot = convertToSnapshot(mediaInfo) else {
            logger.warning("Failed to convert media info to snapshot")
            currentMusic = nil
            songChangeState = .idle
            onUpdate(nil)
            return
        }
        
        logger.info("Full update: \(snapshot.artist) - \(snapshot.title), has artwork: \(snapshot.artworkData != nil), artwork size: \(snapshot.artworkData?.count ?? 0)")
        
        // Check if this is a song change
        let isSongChange = currentMusic == nil || 
                          currentMusic!.title != snapshot.title || 
                          currentMusic!.artist != snapshot.artist
        
        if isSongChange {
            logger.info("Song changed detected")
            
            // If this is the first song (no previous music), trust the artwork
            if currentMusic == nil {
                logger.info("First song, using provided artwork")
                currentMusic = snapshot
                songChangeState = .idle
                onUpdate(snapshot)
                return
            }
            
            // Compare artwork with previous song
            let previousArtwork = currentMusic!.artworkData
            let newArtwork = snapshot.artworkData
            
            // Check if artwork is the same as previous song (old artwork)
            let isSameArtwork = (previousArtwork != nil && newArtwork != nil && previousArtwork == newArtwork)
            
            if isSameArtwork {
                // Artwork is same as previous song - it's old artwork!
                logger.info("Artwork is same as previous song (old artwork), waiting for update...")
                songChangeState = .waitingForArtwork(snapshot)
                // Don't report yet, wait for artwork diff update
            } else if newArtwork != nil && !newArtwork!.isEmpty {
                // Different artwork - this is already the correct artwork!
                logger.info("Artwork is different from previous song (already updated), reporting now")
                currentMusic = snapshot
                songChangeState = .idle
                onUpdate(snapshot)
            } else {
                // No artwork - wait for diff update to confirm (might get empty string or actual artwork)
                logger.info("No artwork in full update, waiting for diff update...")
                songChangeState = .waitingForArtwork(snapshot)
            }
        } else {
            // Same song, state update
            logger.info("Same song, state update")
            currentMusic = snapshot
            songChangeState = .idle
            onUpdate(snapshot)
        }
    }
    
    /// Handle differential update (diff: true) - only changed fields
    private func handleDiffUpdate(_ mediaInfo: MediaRemoteOutput, onUpdate: @escaping (MusicSnapshot?) -> Void) {
        // Check what fields changed
        let hasArtwork = mediaInfo.artworkData != nil
        let hasPlaying = mediaInfo.playing != nil
        let hasElapsedTime = mediaInfo.elapsedTime != nil
        
        logger.info("Diff update - artwork: \(hasArtwork), playing: \(hasPlaying), elapsedTime: \(hasElapsedTime)")
        
        // Case 1: Progress update only - ignore completely
        if hasElapsedTime && !hasArtwork && !hasPlaying {
            logger.debug("Progress update only, ignoring")
            return
        }
        
        // Case 2: Artwork update
        if hasArtwork {
            handleArtworkDiffUpdate(mediaInfo, onUpdate: onUpdate)
            return
        }
        
        // Case 3: Playing status update
        if hasPlaying {
            handlePlayingDiffUpdate(mediaInfo, onUpdate: onUpdate)
            return
        }
        
        // Other diff updates - ignore
        logger.debug("Other diff update, ignoring")
    }
    
    /// Handle artwork diff update
    private func handleArtworkDiffUpdate(_ mediaInfo: MediaRemoteOutput, onUpdate: @escaping (MusicSnapshot?) -> Void) {
        let artworkBase64 = mediaInfo.artworkData!
        
        // Check for empty artwork (clearing signal after song change)
        if artworkBase64.isEmpty {
            logger.info("Artwork cleared (empty string)")
            
            // If waiting for artwork, this means the new song has no artwork
            if case .waitingForArtwork(let pending) = songChangeState {
                logger.info("New song has no artwork, reporting without artwork")
                currentMusic = pending
                songChangeState = .idle
                onUpdate(pending)
            }
            return
        }
        
        // Decode artwork
        logger.info("Artwork update (size: \(artworkBase64.count) chars)")
        guard let artworkData = Data(base64Encoded: artworkBase64) else {
            logger.warning("Failed to decode base64 artwork")
            
            // If waiting, give up and report without artwork
            if case .waitingForArtwork(let pending) = songChangeState {
                logger.info("Artwork decode failed, reporting without artwork")
                currentMusic = pending
                songChangeState = .idle
                onUpdate(pending)
            }
            return
        }
        
        logger.info("Artwork decoded (size: \(artworkData.count) bytes)")
        
        // Check state
        switch songChangeState {
        case .waitingForArtwork(let pending):
            // This is the artwork for the new song!
            logger.info("Received artwork for new song: \(pending.artist) - \(pending.title)")
            
            let updatedSnapshot = MusicSnapshot(
                title: pending.title,
                artist: pending.artist,
                album: pending.album,
                isPlaying: pending.isPlaying,
                bundleIdentifier: pending.bundleIdentifier,
                artworkData: artworkData,
                timestamp: Date()
            )
            
            currentMusic = updatedSnapshot
            songChangeState = .idle
            onUpdate(updatedSnapshot)
            logger.info("Reported song change with correct artwork")
            
        case .idle:
            // Artwork update for current song (shouldn't happen often)
            guard let current = currentMusic else {
                logger.warning("Artwork update in idle state but no current music")
                return
            }
            
            logger.info("Artwork update for current song (updating locally only)")
            
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
            // Don't trigger callback - will be included in next real update
        }
    }
    
    /// Handle playing status diff update
    private func handlePlayingDiffUpdate(_ mediaInfo: MediaRemoteOutput, onUpdate: @escaping (MusicSnapshot?) -> Void) {
        let newPlayingStatus = mediaInfo.playing!
        logger.info("Playing status changed: \(newPlayingStatus)")
        
        // Check state
        switch songChangeState {
        case .waitingForArtwork(let pending):
            // Playing status changed while waiting for artwork
            // Give up waiting and report with current artwork
            logger.info("Playing changed while waiting for artwork, reporting now")
            
            let updatedSnapshot = MusicSnapshot(
                title: pending.title,
                artist: pending.artist,
                album: pending.album,
                isPlaying: newPlayingStatus,
                bundleIdentifier: pending.bundleIdentifier,
                artworkData: pending.artworkData, // Use whatever we have
                timestamp: Date()
            )
            
            currentMusic = updatedSnapshot
            songChangeState = .idle
            onUpdate(updatedSnapshot)
            
        case .idle:
            // Normal playing status update
            guard let current = currentMusic else {
                logger.warning("Playing update but no current music")
                return
            }
            
            let updatedSnapshot = MusicSnapshot(
                title: current.title,
                artist: current.artist,
                album: current.album,
                isPlaying: newPlayingStatus,
                bundleIdentifier: current.bundleIdentifier,
                artworkData: current.artworkData,
                timestamp: Date()
            )
            
            currentMusic = updatedSnapshot
            onUpdate(updatedSnapshot)
        }
    }
    
    private func handleStreamTermination(exitCode: Int32) {
        logger.info("MediaRemote stream terminated with code \(exitCode)")
        
        // Reset state
        songChangeState = .idle
        
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
            logger.info("Converting artwork from base64 (length: \(artworkBase64.count) chars)")
            logger.info("Artwork base64 prefix: \(artworkBase64.prefix(50))")
            logger.info("Artwork base64 suffix: \(artworkBase64.suffix(50))")
            
            artwork = Data(base64Encoded: artworkBase64)
            if let artworkData = artwork {
                logger.info("Artwork decoded successfully (size: \(artworkData.count) bytes)")
            } else {
                logger.warning("Failed to decode base64 artwork data")
                logger.warning("Base64 string may be incomplete or corrupted")
            }
        } else {
            logger.info("No artworkData in media info")
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

