//
//  AppCoordinator.swift
//  share-my-status-client
//
//  Created by Refactor on 2025-01-07.
//

import Foundation
import SwiftUI
import Combine

/// Application coordinator for managing app lifecycle and service coordination
@MainActor
class AppCoordinator: ObservableObject {
    // MARK: - Shared Instance
    static let shared = AppCoordinator()
    
    // MARK: - Properties
    @Published var configuration: AppConfiguration
    @Published var reporter: StatusReporter
    
    private let logger = AppLogger.app
    
    // MARK: - Initialization
    private init() {
        self.configuration = AppConfiguration()
        self.reporter = StatusReporter()
        
        logger.info("AppCoordinator initialized")
        
        // Setup configuration observer
        setupConfigurationObserver()
        
        // Initial configuration sync
        reporter.updateConfiguration(configuration)
    }
    
    // MARK: - Configuration Observer
    private func setupConfigurationObserver() {
        // Observe configuration changes and update reporter
        // Using Combine to observe @Published properties
        configuration.objectWillChange.sink { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                // Delay slightly to ensure all changes are applied
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                self.reporter.updateConfiguration(self.configuration)
            }
        }
    }
    
    // MARK: - Lifecycle
    func applicationDidFinishLaunching() {
        logger.info("Application did finish launching")
        
        // Auto-start reporting if configured
        if configuration.isReportingEnabled && configuration.isValidConfiguration() {
            reporter.startReporting()
        }
    }
    
    func applicationWillTerminate() {
        logger.info("Application will terminate")
        reporter.stopReporting()
    }
}

