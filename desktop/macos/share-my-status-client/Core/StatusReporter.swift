//
//  StatusReporter.swift
//  share-my-status-client
//


import Foundation
import SwiftUI
import Combine

/// Main status reporter that coordinates all services
@MainActor
class StatusReporter: ObservableObject {
    // Published State
    @Published var isReporting = false
    @Published var lastError: Error?
    @Published var reportingStatus = "未启动"
    
    @Published var currentMusic: MusicSnapshot?
    @Published var currentSystem: SystemSnapshot?
    @Published var currentActivity: ActivitySnapshot?
    
    // Services
    private let mediaService: MediaRemoteService
    private let systemService: SystemMonitorService
    private let activityService: ActivityDetectorService
    private let networkService: NetworkService
    private let coverService: CoverService
    
    private let logger = AppLogger.reporter
    
    // Configuration
    private var configuration: AppConfiguration?
    
    // Store previous config state as values (not reference)
    private struct ConfigSnapshot {
        let musicReportingEnabled: Bool
        let systemReportingEnabled: Bool
        let activityReportingEnabled: Bool
        let systemPollingInterval: TimeInterval
        let activityPollingInterval: TimeInterval
        
        init(from config: AppConfiguration) {
            self.musicReportingEnabled = config.musicReportingEnabled
            self.systemReportingEnabled = config.systemReportingEnabled
            self.activityReportingEnabled = config.activityReportingEnabled
            self.systemPollingInterval = config.systemPollingInterval
            self.activityPollingInterval = config.activityPollingInterval
        }
    }
    private var previousConfigSnapshot: ConfigSnapshot?
    
    // Report Timers (for polling services)
    private var systemReportTimer: Timer?
    private var activityReportTimer: Timer?
    
    // Initialization
    init() {
        self.mediaService = MediaRemoteService()
        self.systemService = SystemMonitorService()
        self.activityService = ActivityDetectorService()
        self.networkService = NetworkService()
        self.coverService = CoverService()
        
        logger.info("StatusReporter initialized")
    }
    
    deinit {
        // Clean up timers
        systemReportTimer?.invalidate()
        activityReportTimer?.invalidate()
        
        // Note: Cannot call async stopReporting() from deinit
        // Services will clean up themselves via their own deinit
    }
    
    // Track if configuration update is in progress
    private var isUpdatingConfiguration = false
    
    // Cache for deduplication
    private var lastReportedActivityLabel: String?

    // Configuration Update
    func updateConfiguration(_ config: AppConfiguration) {
        // Prevent concurrent configuration updates
        guard !isUpdatingConfiguration else {
            logger.warning("Configuration update already in progress, skipping")
            return
        }
        
        isUpdatingConfiguration = true
        
        // Capture previous config snapshot (values, not reference)
        let previousSnapshot = previousConfigSnapshot
        
        // Update configuration reference
        self.configuration = config
        
        // Save new snapshot for next update
        previousConfigSnapshot = ConfigSnapshot(from: config)
        
        Task {
            defer { 
                Task { @MainActor in
                    self.isUpdatingConfiguration = false
                }
            }
            
            logger.info("Updating configuration...")
            
            // Update all services
            await mediaService.updateWhitelist(config.musicAppWhitelist)
            await activityService.updateActivityGroups(config.activityGroups)
            await networkService.updateConfiguration(
                endpointURL: config.endpointURL,
                secretKey: config.secretKey
            )
            await coverService.updateConfiguration(
                baseURL: config.endpointURL,
                secretKey: config.secretKey
            )
            
            // Update polling intervals
            await systemService.updatePollingInterval(config.systemPollingInterval)
            await activityService.updatePollingInterval(config.activityPollingInterval)
            
            // Handle reporting state changes
            if !config.isReportingEnabled && isReporting {
                // User disabled reporting entirely
                logger.info("Reporting disabled, stopping all services")
                stopReporting()
            } else if config.isReportingEnabled && !isReporting {
                // User enabled reporting
                logger.info("Reporting enabled, starting services")
                startReporting()
            } else if config.isReportingEnabled && isReporting {
                // Reporting is active, check individual service toggles
                logger.info("Reporting active, checking service toggles")
                await handleServiceToggles(previous: previousSnapshot, current: config)
            }
            
            logger.info("Configuration update completed")
        }
    }
    
    // Handle Individual Service Toggles
    private func handleServiceToggles(previous: ConfigSnapshot?, current: AppConfiguration) async {
        guard let prev = previous else {
            // No previous config - this is initial startup
            // Services should already be started by the initial startReporting() call
            logger.info("No previous configuration, services should already be running")
            return
        }
        
        logger.info("Checking service toggles...")
        logger.info("Music: prev=\(prev.musicReportingEnabled), current=\(current.musicReportingEnabled)")
        logger.info("System: prev=\(prev.systemReportingEnabled), current=\(current.systemReportingEnabled)")
        logger.info("Activity: prev=\(prev.activityReportingEnabled), current=\(current.activityReportingEnabled)")
        
        // Check music service toggle
        if prev.musicReportingEnabled != current.musicReportingEnabled {
            if current.musicReportingEnabled {
                logger.info("Starting music service (user enabled)...")
                await startMusicService()
            } else {
                logger.info("Stopping music service (user disabled)...")
                await stopMusicService()
            }
        } else {
            logger.debug("Music service toggle unchanged")
        }
        
        // Check system service toggle
        if prev.systemReportingEnabled != current.systemReportingEnabled {
            if current.systemReportingEnabled {
                logger.info("Starting system service (user enabled)...")
                await startSystemService()
            } else {
                logger.info("Stopping system service (user disabled)...")
                await stopSystemService()
            }
        }
        
        // Check activity service toggle
        if prev.activityReportingEnabled != current.activityReportingEnabled {
            if current.activityReportingEnabled {
                logger.info("Starting activity service (user enabled)...")
                await startActivityService()
            } else {
                logger.info("Stopping activity service (user disabled)...")
                await stopActivityService()
            }
        }
        
        // Check if polling intervals changed (restart if running)
        if prev.systemPollingInterval != current.systemPollingInterval && current.systemReportingEnabled {
            logger.info("System polling interval changed, restarting...")
            await stopSystemService()
            await startSystemService()
        }
        
        if prev.activityPollingInterval != current.activityPollingInterval && current.activityReportingEnabled {
            logger.info("Activity polling interval changed, restarting...")
            await stopActivityService()
            await startActivityService()
        }
        
        logger.info("Service toggles handling completed")
        await updateReportingStatus()
    }
    
    // Start Reporting
    func startReporting() {
        guard let config = configuration else {
            logger.error("No configuration available")
            reportingStatus = "未配置"
            return
        }
        
        guard config.isValidConfiguration() else {
            logger.error("Invalid configuration")
            reportingStatus = "配置不完整"
            return
        }
        
        logger.info("Starting status reporting...")
        isReporting = true
        lastError = nil
        
        Task {
            // Start each enabled service using dedicated methods
            if config.musicReportingEnabled {
                await startMusicService()
            } else {
                logger.info("Music reporting disabled in config")
            }
            
            if config.systemReportingEnabled {
                await startSystemService()
            } else {
                logger.info("System reporting disabled in config")
            }
            
            if config.activityReportingEnabled {
                await startActivityService()
            } else {
                logger.info("Activity reporting disabled in config")
            }
            
            await updateReportingStatus()
        }
    }
    
    // Stop Reporting
    func stopReporting() {
        logger.info("Stopping status reporting...")
        isReporting = false
        
        Task {
            // Stop all services using dedicated methods
            await stopMusicService()
            await stopSystemService()
            await stopActivityService()
            
            await updateReportingStatus()
        }
    }
    
    // Individual Service Control
    
    /// Start music service only
    private func startMusicService() async {
        guard let config = configuration, config.musicReportingEnabled else { 
            logger.info("Music reporting disabled, skipping start")
            return 
        }
        
        // Check if already running
        let isAlreadyStreaming = await mediaService.getIsStreaming()
        if isAlreadyStreaming {
            logger.warning("Music service already streaming, skipping start")
            return
        }
        
        logger.info("Starting music service...")
        do {
            // Register callback for music changes
            await mediaService.registerCallback { [weak self] music in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    
                    // Check if this is only an artwork update (same song)
                    let isArtworkOnlyUpdate = music != nil && 
                                             self.currentMusic != nil &&
                                             music!.title == self.currentMusic!.title &&
                                             music!.artist == self.currentMusic!.artist
                    
                    if let music = music {
                        if isArtworkOnlyUpdate {
                            self.logger.info("Artwork update for: \(music.artist) - \(music.title)")
                        } else {
                            self.logger.info("Music change event: \(music.artist) - \(music.title)")
                        }
                    } else {
                        self.logger.info("Music change event: no music playing")
                    }
                    
                    // Always update current music state
                    self.currentMusic = music
                    
                    // Only report if it's not just an artwork update
                    if !isArtworkOnlyUpdate {
                        await self.reportMusicChange(music)
                    } else {
                        self.logger.info("Skipping report for artwork-only update (will be included in next report)")
                    }
                }
            }
            
            // Start streaming
            try await mediaService.start()
            logger.info("Music service started successfully")
        } catch {
            logger.error("Failed to start music service: \(error)")
        }
    }
    
    /// Stop music service only
    private func stopMusicService() async {
        logger.info("Stopping music service...")
        
        // Check if music service is actually running
        let isStreaming = await mediaService.getIsStreaming()
        logger.info("Music service streaming status before stop: \(isStreaming)")
        
        await mediaService.stop()
        
        // Verify it stopped
        let isStillStreaming = await mediaService.getIsStreaming()
        logger.info("Music service streaming status after stop: \(isStillStreaming)")
        
        currentMusic = nil
        logger.info("Music service stopped")
    }
    
    /// Start system monitoring service only
    private func startSystemService() async {
        guard let config = configuration, config.systemReportingEnabled else { return }
        
        logger.info("Starting system service...")
        do {
            await systemService.updatePollingInterval(config.systemPollingInterval)
            try await systemService.start()
            await setupSystemReportTimer(interval: config.systemPollingInterval)
            logger.info("System service started")
        } catch {
            logger.error("Failed to start system service: \(error)")
        }
    }
    
    /// Stop system monitoring service only
    private func stopSystemService() async {
        logger.info("Stopping system service...")
        await systemService.stop()
        systemReportTimer?.invalidate()
        systemReportTimer = nil
        currentSystem = nil
    }
    
    /// Start activity detection service only
    private func startActivityService() async {
        guard let config = configuration, config.activityReportingEnabled else { return }
        
        logger.info("Starting activity service...")
        do {
            await activityService.updatePollingInterval(config.activityPollingInterval)
            try await activityService.start()
            await setupActivityReportTimer(interval: config.activityPollingInterval)
            logger.info("Activity service started")
        } catch {
            logger.error("Failed to start activity service: \(error)")
        }
    }
    
    /// Stop activity detection service only
    private func stopActivityService() async {
        logger.info("Stopping activity service...")
        await activityService.stop()
        activityReportTimer?.invalidate()
        activityReportTimer = nil
        currentActivity = nil
        
        // Clear cached label when stopping service
        lastReportedActivityLabel = nil
    }
    
    // Report Timers
    
    /// Setup system monitoring report timer (polling-based)
    private func setupSystemReportTimer(interval: TimeInterval) async {
        systemReportTimer?.invalidate()
        
        systemReportTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.reportSystemStatus()
            }
        }
        
        logger.info("System report timer set to \(interval) seconds")
    }
    
    /// Setup activity detection report timer (polling-based)
    private func setupActivityReportTimer(interval: TimeInterval) async {
        activityReportTimer?.invalidate()
        
        activityReportTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.reportActivityStatus()
            }
        }
        
        logger.info("Activity report timer set to \(interval) seconds")
    }
    
    // Report Methods
    
    /// Report music change immediately (event-driven)
    private func reportMusicChange(_ music: MusicSnapshot?) async {
        guard let config = configuration, config.isReportingEnabled else {
            return
        }
        
        logger.debug("Reporting music change...")
        
        // If no music is playing and we don't have previous music, skip reporting
        // This avoids reporting empty state on app startup
        if music == nil && currentMusic == nil {
            logger.info("No music playing and no previous music, skipping report")
            return
        }
        
        var musicInfo: MusicInfo? = nil
        
        // Use currentMusic which may have been updated with artwork via diff updates
        if let music = currentMusic {
            logger.info("Music changed: \(music.artist) - \(music.title), playing: \(music.isPlaying)")
            var coverHash: String? = nil
            
            // Upload cover if we have artwork data
            if let artworkData = music.artworkData {
                logger.info("Uploading cover (size: \(artworkData.count) bytes)")
                do {
                    coverHash = try await coverService.checkAndUploadCover(artworkData: artworkData)
                    logger.info("Cover uploaded with hash: \(coverHash ?? "nil")")
                } catch {
                    logger.error("Failed to upload cover: \(error)")
                }
            } else {
                logger.info("No artwork data available for current music")
            }
            
            musicInfo = music.toMusicInfo(coverHash: coverHash)
        } else {
            logger.info("Music stopped (was playing: \(music?.title ?? "unknown"))")
        }
        
        // Create report event with only music info
        let event = ReportEvent(
            system: nil,
            music: musicInfo,
            activity: nil
        )
        
        await sendReport(event: event, source: "music")
    }
    
    /// Report system status periodically (polling-based)
    private func reportSystemStatus() async {
        guard let config = configuration, config.isReportingEnabled, config.systemReportingEnabled else {
            return
        }
        
        logger.debug("Reporting system status...")
        
        // Get current system snapshot
        currentSystem = await systemService.getCurrentSnapshot()
        guard let systemInfo = currentSystem?.toSystemInfo() else {
            logger.info("No system data to report")
            return
        }
        
        logger.info("System status collected")
        
        // Create report event with only system info
        let event = ReportEvent(
            system: systemInfo,
            music: nil,
            activity: nil
        )
        
        await sendReport(event: event, source: "system")
    }
    
    /// Report activity status periodically (polling-based)
    private func reportActivityStatus() async {
        guard let config = configuration, config.isReportingEnabled, config.activityReportingEnabled else {
            return
        }
        
        logger.debug("Reporting activity status...")
        
        // Get current activity
        currentActivity = await activityService.getCurrentActivity()
        guard let activityInfo = currentActivity?.toActivityInfo() else {
            logger.info("No activity data to report")
            return
        }
        
        // Check if label has changed (deduplication)
        if let lastLabel = lastReportedActivityLabel, lastLabel == activityInfo.label {
            logger.debug("Activity label unchanged (\(activityInfo.label)), skipping report")
            return
        }
        
        logger.info("Activity status collected: \(activityInfo.label)")
        
        // Update last reported label
        lastReportedActivityLabel = activityInfo.label
        
        // Create report event with only activity info
        let event = ReportEvent(
            system: nil,
            music: nil,
            activity: activityInfo
        )
        
        await sendReport(event: event, source: "activity")
    }
    
    /// Send report to server
    private func sendReport(event: ReportEvent, source: String) async {
        let request = BatchReportRequest(events: [event])
        
        do {
            let response = try await networkService.reportStatus(request)
            lastError = nil
            
            logger.info("[\(source)] Report sent successfully: accepted=\(response.accepted ?? 0)")
            
            await updateReportingStatus()
        } catch {
            logger.error("[\(source)] Failed to send report: \(error)")
            lastError = error
            await updateReportingStatus()
        }
    }
    
    // Update Status
    private func updateReportingStatus() async {
        guard let config = configuration else {
            reportingStatus = "未配置"
            return
        }
        
        if !config.isReportingEnabled {
            reportingStatus = "已禁用"
            return
        }
        
        if !isReporting {
            reportingStatus = "未启动"
            return
        }
        
        let connected = await networkService.getConnectionStatus()
        if !connected {
            reportingStatus = "网络未连接"
            return
        }
        
        if let error = lastError {
            reportingStatus = "错误: \(error.localizedDescription)"
            return
        }
        
        var activeModules: [String] = []
        
        if config.musicReportingEnabled, await mediaService.isActive() {
            activeModules.append("音乐")
        }
        
        if config.systemReportingEnabled, await systemService.isActive() {
            activeModules.append("系统")
        }
        
        if config.activityReportingEnabled, await activityService.isActive() {
            activeModules.append("活动")
        }
        
        if activeModules.isEmpty {
            reportingStatus = "无活动模块"
        } else {
            reportingStatus = "正在上报: \(activeModules.joined(separator: ", "))"
        }
    }
    
    // Status Summary
    func getStatusSummary() -> String {
        var summary: [String] = []
        
        if let music = currentMusic {
            summary.append("🎵 \(music.artist) - \(music.title)")
        }
        
        if let system = currentSystem {
            var systemInfo: [String] = []
            if let battery = system.batteryPercentage {
                let icon = system.isCharging == true ? "🔌" : "🔋"
                systemInfo.append("\(icon) \(battery)%")
            }
            if let cpu = system.cpuPercentage {
                systemInfo.append("💻 CPU \(cpu)%")
            }
            if let memory = system.memoryPercentage {
                systemInfo.append("🧠 内存 \(memory)%")
            }
            if !systemInfo.isEmpty {
                summary.append(systemInfo.joined(separator: " "))
            }
        }
        
        if let activity = currentActivity {
            let icon = activity.isIdle ? "😴" : "👤"
            summary.append("\(icon) \(activity.activityTag): \(activity.activeApplication)")
        }
        
        return summary.isEmpty ? "无状态数据" : summary.joined(separator: "\n")
    }
    
    // Network Statistics
    func getNetworkStatistics() async -> (lastReportTime: Date?, reportCount: Int, isConnected: Bool) {
        return await networkService.getStatistics()
    }
}

