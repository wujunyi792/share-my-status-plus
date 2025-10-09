//
//  ActivityDetectorService.swift
//  share-my-status-client
//


import Foundation
import AppKit
import ApplicationServices

/// Actor-based activity detection service for thread-safe activity tracking
actor ActivityDetectorService: PollingMonitoringService {
    // PollingMonitoringService Conformance
    let monitoringType: MonitoringType = .polling
    
    private(set) var pollingInterval: TimeInterval = 5.0
    
    func isActive() -> Bool {
        return isDetecting
    }
    
    func start() async throws {
        await startDetection(interval: pollingInterval)
    }
    
    func stop() async {
        stopDetection()
    }
    
    func updatePollingInterval(_ interval: TimeInterval) async {
        let wasDetecting = isDetecting
        
        // Stop current detection
        if wasDetecting {
            stopDetection()
        }
        
        // Update interval
        pollingInterval = interval
        logger.info("Polling interval updated to \(interval)s")
        
        // Restart if it was running
        if wasDetecting {
            await startDetection(interval: interval)
        }
    }
    
    // Properties
    private let logger = AppLogger.activity
    private var currentActivity: ActivitySnapshot?
    private var isDetecting = false
    private var detectionTask: Task<Void, Never>?
    
    private var activityGroups: [ActivityGroup] = []
    
    // Lifecycle
    init() {
        // Check permissions on init but don't block
        if !AccessibilityPermissionChecker.isAccessibilityGranted() {
            logger.warning("Accessibility permissions not granted. Activity detection will be limited.")
        }
    }
    
    deinit {
        detectionTask?.cancel()
    }
    
    // Configuration
    func updateActivityGroups(_ groups: [ActivityGroup]) {
        self.activityGroups = groups
    }
    
    // Detection Control
    private func startDetection(interval: TimeInterval) async {
        guard !isDetecting else {
            logger.warning("Already detecting")
            return
        }
        
        logger.info("Starting activity detection with interval \(interval)s...")
        isDetecting = true
        pollingInterval = interval
        
        detectionTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.detectActivity()
                if let interval = await self?.pollingInterval {
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
            }
        }
    }
    
    private func stopDetection() {
        guard isDetecting else { return }
        
        logger.info("Stopping activity detection...")
        isDetecting = false
        detectionTask?.cancel()
        detectionTask = nil
        currentActivity = nil
    }
    
    // Get Current State
    func getCurrentActivity() -> ActivitySnapshot? {
        return currentActivity
    }
    
    func getIsDetecting() -> Bool {
        return isDetecting
    }
    
    // Activity Detection
    private func detectActivity() async {
        guard AccessibilityPermissionChecker.isAccessibilityGranted() else {
            logger.warning("Accessibility permissions not granted. Please grant permissions in System Settings.")
            return
        }
        
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return
        }
        
        let windowTitle = getActiveWindowTitle()
        let idleTime = getIdleTime()
        
        let activityTag = mapActivityTag(
            bundleId: frontmostApp.bundleIdentifier ?? "",
            appName: frontmostApp.localizedName ?? "",
            windowTitle: windowTitle ?? ""
        )
        
        let snapshot = ActivitySnapshot(
            activeApplication: frontmostApp.localizedName ?? "Unknown App",
            bundleIdentifier: frontmostApp.bundleIdentifier,
            windowTitle: windowTitle,
            idleTimeSeconds: idleTime,
            activityTag: activityTag,
            timestamp: Date()
        )
        
        currentActivity = snapshot
        logger.debug("Activity detected: \(activityTag) - \(snapshot.activeApplication)")
    }
    
    // Window Title Detection
    private func getActiveWindowTitle() -> String? {
        guard AccessibilityPermissionChecker.isAccessibilityGranted() else { return nil }
        
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )
        guard result == .success, let app = focusedApp else { return nil }
        
        var focusedWindow: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(
            app as! AXUIElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )
        guard windowResult == .success, let window = focusedWindow else { return nil }
        
        var windowTitle: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(
            window as! AXUIElement,
            kAXTitleAttribute as CFString,
            &windowTitle
        )
        guard titleResult == .success, let title = windowTitle as? String else { return nil }
        
        return title
    }
    
    // Idle Time Detection
    private func getIdleTime() -> TimeInterval {
        return CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .mouseMoved)
    }
    
    // Activity Tag Mapping
    private func mapActivityTag(bundleId: String, appName: String, windowTitle: String) -> String {
        // Check enabled activity groups only
        for group in activityGroups where group.isEnabled {
            if group.bundleIds.contains(bundleId) {
                return group.name
            }
        }
        
        // If no enabled rule matches, return default tag
        // Note: Disabled rules will not match, so apps will fall through to "其他"
        return "其他"
    }
}

