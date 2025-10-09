//
//  Logger.swift
//  share-my-status-client
//


import Foundation
import os.log

/// Application logger
struct AppLogger {
    private let subsystem = "com.share-my-status.client"
    
    enum Category: String {
        case app = "App"
        case media = "Media"
        case system = "System"
        case activity = "Activity"
        case network = "Network"
        case cover = "Cover"
        case reporter = "Reporter"
    }
    
    private let logger: os.Logger
    
    init(category: Category) {
        if #available(macOS 11.0, *) {
            self.logger = os.Logger(subsystem: subsystem, category: category.rawValue)
        } else {
            // Fallback for older versions
            self.logger = os.Logger(subsystem: subsystem, category: category.rawValue)
        }
    }
    
    func debug(_ message: String) {
        if #available(macOS 11.0, *) {
            logger.debug("\(message)")
        } else {
            os_log("%{public}@", log: OSLog(subsystem: subsystem, category: "Debug"), type: .debug, message)
        }
    }
    
    func info(_ message: String) {
        if #available(macOS 11.0, *) {
            logger.info("\(message)")
        } else {
            os_log("%{public}@", log: OSLog(subsystem: subsystem, category: "Info"), type: .info, message)
        }
    }
    
    func warning(_ message: String) {
        if #available(macOS 11.0, *) {
            logger.warning("\(message)")
        } else {
            os_log("%{public}@", log: OSLog(subsystem: subsystem, category: "Warning"), type: .default, message)
        }
    }
    
    func error(_ message: String) {
        if #available(macOS 11.0, *) {
            logger.error("\(message)")
        } else {
            os_log("%{public}@", log: OSLog(subsystem: subsystem, category: "Error"), type: .error, message)
        }
    }
    
    func fault(_ message: String) {
        if #available(macOS 11.0, *) {
            logger.fault("\(message)")
        } else {
            os_log("%{public}@", log: OSLog(subsystem: subsystem, category: "Fault"), type: .fault, message)
        }
    }
}

// Global Logger Instances

extension AppLogger {
    static let app = AppLogger(category: .app)
    static let media = AppLogger(category: .media)
    static let system = AppLogger(category: .system)
    static let activity = AppLogger(category: .activity)
    static let network = AppLogger(category: .network)
    static let cover = AppLogger(category: .cover)
    static let reporter = AppLogger(category: .reporter)
}

