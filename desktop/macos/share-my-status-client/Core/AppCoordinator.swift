//
//  AppCoordinator.swift
//  share-my-status-client
//


import Foundation
import SwiftUI
import Combine
import AppKit

/// Application coordinator for managing app lifecycle and service coordination
@MainActor
class AppCoordinator: ObservableObject {
    // Shared Instance
    static let shared = AppCoordinator()
    
    // Properties
    @Published var configuration: AppConfiguration
    @Published var reporter: StatusReporter
    @Published var availableUpdate: ClientVersionInfo?
    
    // GitHub Release auto-update
    @Published var updatePhase: AppUpdatePhase = .idle
    
    private let logger = AppLogger.app
    private var cancellables = Set<AnyCancellable>()
    private let versionService = VersionUpdateService()
    private let githubReleaseService = GitHubReleaseService()
    private var updateCheckTask: Task<Void, Never>?
    
    // Initialization
    private init() {
        self.configuration = AppConfiguration()
        self.reporter = StatusReporter()
        
        logger.info("AppCoordinator initialized")
        
        // Setup configuration observer for future changes
        setupConfigurationObserver()
    }
    
    // Configuration Observer
    private func setupConfigurationObserver() {
        logger.info("Setting up configuration observer")
        
        configuration.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                logger.info("Configuration changed, updating reporter (without auto-start)")
                Task { @MainActor in
                    self.reporter.updateConfiguration(self.configuration, autoStart: false)
                    await self.versionService.updateConfiguration(baseURL: self.configuration.endpointURL)
                }
            }
            .store(in: &cancellables)
    }
    
    // Lifecycle
    func applicationDidFinishLaunching() {
        logger.info("Application did finish launching")
        logger.info("Configuration: isValid=\(configuration.isValidConfiguration())")
        
        logger.info("Performing initial configuration sync...")
        
        let shouldAutoStart = reporter.getSavedReportingState()
        logger.info("Saved reporting state: \(shouldAutoStart)")
        
        if shouldAutoStart && configuration.isValidConfiguration() {
            logger.info("Auto-starting reporting from saved state...")
            reporter.updateConfiguration(configuration, autoStart: true)
        } else {
            logger.info("Not auto-starting reporting")
            reporter.updateConfiguration(configuration, autoStart: false)
        }
        
        Task { @MainActor in
            await self.versionService.updateConfiguration(baseURL: self.configuration.endpointURL)
        }
        
        // Legacy server-based update check
        checkAndPromptUpdate()
        
        // GitHub Release auto-update check on launch
        checkGitHubUpdate()
        
        // Periodic GitHub update check (every 2 hours)
        startPeriodicUpdateCheck()
    }
    
    // MARK: - Legacy server-based update check
    
    func checkAndPromptUpdate(forceManual: Bool = false) {
        Task { @MainActor in
            let version = AppVersionUtility.appVersion
            let buildStr = AppVersionUtility.buildNumber
            let build: Int32 = Int32(buildStr) ?? 0
            
            do {
                if let latest = try await self.versionService.checkForUpdates(version: version, build: build) {
                    self.availableUpdate = latest
                } else {
                    self.logger.info("No updates available (server)")
                }
            } catch {
                self.logger.error("Failed to check updates (server): \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - GitHub Release auto-update
    
    func checkGitHubUpdate() {
        switch updatePhase {
        case .idle, .error:
            break
        default:
            logger.info("Update check skipped: already in progress")
            return
        }
        
        updatePhase = .checking
        
        Task { @MainActor in
            do {
                if let info = try await githubReleaseService.checkForUpdate() {
                    self.updatePhase = .available(info)
                    self.logger.info("GitHub update available: \(info.version) (\(info.buildNumber))")
                } else {
                    self.updatePhase = .idle
                    self.logger.info("No GitHub updates available")
                }
            } catch {
                self.updatePhase = .error(error.localizedDescription)
                self.logger.error("GitHub update check failed: \(error.localizedDescription)")
            }
        }
    }
    
    func downloadGitHubUpdate() {
        guard case .available(let info) = updatePhase else { return }
        
        updatePhase = .downloading(info, progress: 0)
        
        Task { @MainActor in
            do {
                let localURL = try await self.githubReleaseService.downloadUpdate(info: info) { [weak self] progress in
                    Task { @MainActor in
                        self?.updatePhase = .downloading(info, progress: progress)
                    }
                }
                self.updatePhase = .downloaded(info, localURL: localURL)
                self.logger.info("Update downloaded: \(localURL.path)")
            } catch {
                self.updatePhase = .error("下载失败: \(error.localizedDescription)")
                self.logger.error("Download failed: \(error.localizedDescription)")
            }
        }
    }
    
    func installGitHubUpdate() {
        guard case .downloaded(_, let localURL) = updatePhase else { return }
        
        updatePhase = .installing
        
        Task { @MainActor in
            do {
                try await self.githubReleaseService.installUpdate(zipURL: localURL)
            } catch {
                self.updatePhase = .error("安装失败: \(error.localizedDescription)")
                self.logger.error("Install failed: \(error.localizedDescription)")
            }
        }
    }
    
    func dismissUpdateError() {
        updatePhase = .idle
    }
    
    private func startPeriodicUpdateCheck() {
        updateCheckTask?.cancel()
        updateCheckTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2 * 60 * 60 * 1_000_000_000) // 2 hours
                if case .idle = self.updatePhase {
                    self.checkGitHubUpdate()
                }
            }
        }
    }
    
    func applicationWillTerminate() {
        logger.info("Application will terminate")
        updateCheckTask?.cancel()
        reporter.stopReporting()
    }
}
