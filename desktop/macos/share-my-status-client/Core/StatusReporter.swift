//
//  StatusReporter.swift
//  share-my-status-client
//
//  Created by Refactor on 2025-01-07.
//

import Foundation
import SwiftUI
import Combine

/// Main status reporter that coordinates all services
@MainActor
class StatusReporter: ObservableObject {
    // MARK: - Published State
    @Published var isReporting = false
    @Published var lastError: Error?
    @Published var reportingStatus = "未启动"
    
    @Published var currentMusic: MusicSnapshot?
    @Published var currentSystem: SystemSnapshot?
    @Published var currentActivity: ActivitySnapshot?
    
    // MARK: - Services
    private let mediaService: MediaRemoteService
    private let systemService: SystemMonitorService
    private let activityService: ActivityDetectorService
    private let networkService: NetworkService
    private let coverService: CoverService
    
    private let logger = AppLogger.reporter
    
    // MARK: - Configuration
    private var configuration: AppConfiguration?
    
    // MARK: - Report Timers (for polling services)
    private var systemReportTimer: Timer?
    private var activityReportTimer: Timer?
    
    // MARK: - Initialization
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
    
    // MARK: - Configuration Update
    func updateConfiguration(_ config: AppConfiguration) {
        self.configuration = config
        
        Task {
            // Update all services
            await mediaService.updateWhitelist(config.musicAppWhitelist)
            await activityService.updateBlacklist(config.activityAppBlacklist)
            await activityService.updateRules(config.activityRules)
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
            
            // Start/stop based on config
            if config.isReportingEnabled && !isReporting {
                startReporting()
            } else if !config.isReportingEnabled && isReporting {
                stopReporting()
            } else if config.isReportingEnabled && isReporting {
                // Restart to apply new intervals
                stopReporting()
                startReporting()
            }
        }
    }
    
    // MARK: - Start Reporting
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
            // Start music service (event-driven) - reports immediately on change
            if config.musicReportingEnabled {
                logger.info("Starting music reporting service (event-driven)...")
                do {
                    // Register callback for music changes
                    await mediaService.registerCallback { [weak self] music in
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }
                            
                            if let music = music {
                                self.logger.info("Music change event: \(music.artist) - \(music.title)")
                            } else {
                                self.logger.info("Music change event: no music playing")
                            }
                            
                            self.currentMusic = music
                            
                            // Immediately report music change
                            await self.reportMusicChange(music)
                        }
                    }
                    
                    // Start streaming
                    try await mediaService.start()
                    logger.info("Music streaming service started (event-driven)")
                } catch {
                    logger.error("Failed to start music streaming: \(error)")
                }
            } else {
                logger.info("Music reporting disabled in config")
            }
            
            // Start system monitoring (polling) - reports at intervals
            if config.systemReportingEnabled {
                logger.info("Starting system monitoring (polling, interval: \(config.systemPollingInterval)s)...")
                do {
                    await systemService.updatePollingInterval(config.systemPollingInterval)
                    try await systemService.start()
                    await setupSystemReportTimer(interval: config.systemPollingInterval)
                    logger.info("System monitoring started")
                } catch {
                    logger.error("Failed to start system monitoring: \(error)")
                }
            } else {
                logger.info("System reporting disabled in config")
            }
            
            // Start activity detection (polling) - reports at intervals
            if config.activityReportingEnabled {
                logger.info("Starting activity detection (polling, interval: \(config.activityPollingInterval)s)...")
                do {
                    await activityService.updatePollingInterval(config.activityPollingInterval)
                    try await activityService.start()
                    await setupActivityReportTimer(interval: config.activityPollingInterval)
                    logger.info("Activity detection started")
                } catch {
                    logger.error("Failed to start activity detection: \(error)")
                }
            } else {
                logger.info("Activity reporting disabled in config")
            }
            
            await updateReportingStatus()
        }
    }
    
    // MARK: - Stop Reporting
    func stopReporting() {
        logger.info("Stopping status reporting...")
        isReporting = false
        
        Task {
            // Stop all monitoring services
            await mediaService.stop()
            await systemService.stop()
            await activityService.stop()
            
            // Invalidate all report timers
            systemReportTimer?.invalidate()
            systemReportTimer = nil
            
            activityReportTimer?.invalidate()
            activityReportTimer = nil
            
            // Clear current state
            currentMusic = nil
            currentSystem = nil
            currentActivity = nil
            
            await updateReportingStatus()
        }
    }
    
    // MARK: - Report Timers
    
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
    
    // MARK: - Report Methods
    
    /// Report music change immediately (event-driven)
    private func reportMusicChange(_ music: MusicSnapshot?) async {
        guard let config = configuration, config.isReportingEnabled else {
            return
        }
        
        logger.debug("Reporting music change...")
        
        var musicInfo: MusicInfo? = nil
        
        if let music = music {
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
            }
            
            musicInfo = music.toMusicInfo(coverHash: coverHash)
        } else {
            logger.info("Music stopped or no music playing")
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
        
        logger.info("Activity status collected: \(activityInfo.label)")
        
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
    
    // MARK: - Update Status
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
            activeModules.append("音乐(事件)")
        }
        
        if config.systemReportingEnabled, await systemService.isActive() {
            activeModules.append("系统(轮询)")
        }
        
        if config.activityReportingEnabled, await activityService.isActive() {
            activeModules.append("活动(轮询)")
        }
        
        if activeModules.isEmpty {
            reportingStatus = "无活动模块"
        } else {
            reportingStatus = "正在上报: \(activeModules.joined(separator: ", "))"
        }
    }
    
    // MARK: - Status Summary
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
    
    // MARK: - Network Statistics
    func getNetworkStatistics() async -> (lastReportTime: Date?, reportCount: Int, isConnected: Bool) {
        return await networkService.getStatistics()
    }
}

