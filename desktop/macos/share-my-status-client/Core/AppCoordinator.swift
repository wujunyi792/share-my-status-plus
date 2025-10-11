//
//  AppCoordinator.swift
//  share-my-status-client
//


import Foundation
import SwiftUI
import Combine

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
    
    // Initialization
    private init() {
        self.configuration = AppConfiguration()
        self.reporter = StatusReporter()
        
        logger.info("AppCoordinator initialized")
        
        // Setup configuration observer for future changes
        setupConfigurationObserver()
        
        // Note: Initial configuration sync will happen in applicationDidFinishLaunching
        // to avoid race conditions during startup
    }
    
    // Configuration Observer
    private func setupConfigurationObserver() {
        // Observe configuration changes and update reporter
        // Using Combine to observe @Published properties
        logger.info("Setting up configuration observer")
        
        configuration.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                logger.info("Configuration changed, updating reporter (without auto-start)")
                Task { @MainActor in
                    // Update configuration only, do not auto-start reporting
                    // The user controls reporting state through manual start/stop buttons
                    self.reporter.updateConfiguration(self.configuration, autoStart: false)
                }
            }
            .store(in: &cancellables)
    }
    
    // Lifecycle
    func applicationDidFinishLaunching() {
        logger.info("Application did finish launching")
        logger.info("Configuration: isValid=\(configuration.isValidConfiguration())")
        
        // Perform initial configuration sync
        logger.info("Performing initial configuration sync...")
        
        // Check if reporting was enabled in previous session
        let shouldAutoStart = reporter.getSavedReportingState()
        logger.info("Saved reporting state: \(shouldAutoStart)")
        
        if shouldAutoStart && configuration.isValidConfiguration() {
            // Auto-start reporting if it was enabled before and configuration is valid
            logger.info("Auto-starting reporting from saved state...")
            reporter.updateConfiguration(configuration, autoStart: true)
        } else {
            // Just update configuration without auto-starting
            logger.info("Not auto-starting reporting")
            reporter.updateConfiguration(configuration, autoStart: false)
        }
    }
    
    func applicationWillTerminate() {
        logger.info("Application will terminate")
        reporter.stopReporting()
    }
}

