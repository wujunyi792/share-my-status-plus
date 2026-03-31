//
//  AppCoordinator.swift
//  share-my-status-client
//


import Foundation
import SwiftUI
import Combine
import AppKit
import Sparkle

/// Application coordinator for managing app lifecycle and service coordination
@MainActor
class AppCoordinator: ObservableObject {
    // Shared Instance
    static let shared = AppCoordinator()
    
    // Properties
    @Published var configuration: AppConfiguration
    @Published var reporter: StatusReporter
    
    private let logger = AppLogger.app
    private var cancellables = Set<AnyCancellable>()
    private lazy var sparkleUpdaterController = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    
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
        
        sparkleUpdaterController.startUpdater()
    }
    
    func checkForUpdates() {
        sparkleUpdaterController.checkForUpdates(nil)
    }
    
    var canCheckForUpdates: Bool {
        sparkleUpdaterController.updater.canCheckForUpdates
    }
    
    var automaticallyChecksForUpdates: Bool {
        sparkleUpdaterController.updater.automaticallyChecksForUpdates
    }
    
    func applicationWillTerminate() {
        logger.info("Application will terminate")
        reporter.stopReporting()
    }
}
