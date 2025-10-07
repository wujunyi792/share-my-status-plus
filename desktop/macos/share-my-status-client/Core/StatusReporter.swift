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
    private var reportTimer: Timer?
    
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
        // Clean up timer
        reportTimer?.invalidate()
        
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
            
            // Start/stop based on config
            if config.isReportingEnabled && !isReporting {
                startReporting()
            } else if !config.isReportingEnabled && isReporting {
                stopReporting()
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
            // Start all enabled services
            if config.musicReportingEnabled {
                logger.info("Starting music reporting service...")
                do {
                    try await mediaService.startStreaming { [weak self] music in
                        Task { @MainActor [weak self] in
                            if let music = music {
                                self?.logger.info("Music update received: \(music.artist) - \(music.title)")
                            } else {
                                self?.logger.info("Music update received: nil (no music playing)")
                            }
                            self?.currentMusic = music
                        }
                    }
                    logger.info("Music streaming service started successfully")
                } catch {
                    logger.error("Failed to start music streaming: \(error)")
                }
            } else {
                logger.info("Music reporting disabled in config")
            }
            
            if config.systemReportingEnabled {
                await systemService.startMonitoring(interval: 10)
            }
            
            if config.activityReportingEnabled {
                await activityService.startDetection(interval: 5)
            }
            
            // Setup report timer
            await setupReportTimer()
            
            await updateReportingStatus()
        }
    }
    
    // MARK: - Stop Reporting
    func stopReporting() {
        logger.info("Stopping status reporting...")
        isReporting = false
        
        Task {
            await mediaService.stopStreaming()
            await systemService.stopMonitoring()
            await activityService.stopDetection()
            
            reportTimer?.invalidate()
            reportTimer = nil
            
            currentMusic = nil
            currentSystem = nil
            currentActivity = nil
            
            await updateReportingStatus()
        }
    }
    
    // MARK: - Report Timer
    private func setupReportTimer() async {
        reportTimer?.invalidate()
        
        guard let config = configuration else { return }
        
        let interval = config.reportInterval
        reportTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performReport()
            }
        }
        
        logger.info("Report timer set to \(interval) seconds")
    }
    
    // MARK: - Perform Report
    func performReport() async {
        guard let config = configuration, config.isReportingEnabled else {
            return
        }
        
        logger.debug("Performing status report...")
        
        // Collect current state from all services
        var musicInfo: MusicInfo? = nil
        var systemInfo: SystemInfo? = nil
        var activityInfo: ActivityInfo? = nil
        
        // Get music info (with cover upload if needed)
        if config.musicReportingEnabled {
            if let music = currentMusic {
                logger.info("Current music: \(music.artist) - \(music.title), playing: \(music.isPlaying)")
                var coverHash: String? = nil
                
                // Upload cover if we have artwork data
                if let artworkData = music.artworkData {
                    logger.info("Attempting to upload cover (size: \(artworkData.count) bytes)")
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
                logger.info("Music info prepared for report")
            } else {
                logger.info("Music reporting enabled but no current music available")
            }
        }
        
        // Get system info
        if config.systemReportingEnabled {
            currentSystem = await systemService.getCurrentSnapshot()
            systemInfo = currentSystem?.toSystemInfo()
            if systemInfo != nil {
                logger.info("System info prepared for report")
            }
        }
        
        // Get activity info
        if config.activityReportingEnabled {
            currentActivity = await activityService.getCurrentActivity()
            activityInfo = currentActivity?.toActivityInfo()
            if activityInfo != nil {
                logger.info("Activity info prepared: \(activityInfo!.label)")
            } else {
                logger.info("Activity reporting enabled but no activity detected")
            }
        }
        
        // Check if we have any data to report
        guard musicInfo != nil || systemInfo != nil || activityInfo != nil else {
            logger.info("No data to report (music: nil, system: nil, activity: nil)")
            return
        }
        
        logger.info("Preparing report - music: \(musicInfo != nil), system: \(systemInfo != nil), activity: \(activityInfo != nil)")
        
        // Create report event
        let event = ReportEvent(
            system: systemInfo,
            music: musicInfo,
            activity: activityInfo
        )
        
        let request = BatchReportRequest(events: [event])
        
        // Send report
        do {
            let response = try await networkService.reportStatus(request)
            lastError = nil
            
            logger.info("Report sent successfully: accepted=\(response.accepted ?? 0)")
            
            await updateReportingStatus()
        } catch {
            logger.error("Failed to send report: \(error)")
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
        
        if config.musicReportingEnabled, await mediaService.getIsStreaming() {
            activeModules.append("音乐")
        }
        
        if config.systemReportingEnabled, await systemService.getIsMonitoring() {
            activeModules.append("系统")
        }
        
        if config.activityReportingEnabled, await activityService.getIsDetecting() {
            activeModules.append("活动")
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

