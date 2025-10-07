//
//  ActivityDetectorService.swift
//  share-my-status-client
//
//  Created by Refactor on 2025-01-07.
//

import Foundation
import AppKit
import ApplicationServices

/// Actor-based activity detection service for thread-safe activity tracking
actor ActivityDetectorService {
    // MARK: - Properties
    private let logger = AppLogger.activity
    private var currentActivity: ActivitySnapshot?
    private var isDetecting = false
    private var detectionTask: Task<Void, Never>?
    
    private var blacklistedBundleIds: [String] = []
    private var activityRules: [ActivityRule] = []
    
    // MARK: - Lifecycle
    init() {
        // Check permissions on init but don't block
        if !AccessibilityPermissionChecker.isAccessibilityGranted() {
            logger.warning("Accessibility permissions not granted. Activity detection will be limited.")
        }
    }
    
    deinit {
        detectionTask?.cancel()
    }
    
    // MARK: - Configuration
    func updateBlacklist(_ bundleIds: [String]) {
        self.blacklistedBundleIds = bundleIds
    }
    
    func updateRules(_ rules: [ActivityRule]) {
        self.activityRules = rules
    }
    
    // MARK: - Detection Control
    func startDetection(interval: TimeInterval = 5) async {
        guard !isDetecting else {
            logger.warning("Already detecting")
            return
        }
        
        logger.info("Starting activity detection...")
        isDetecting = true
        
        detectionTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.detectActivity()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }
    
    func stopDetection() {
        guard isDetecting else { return }
        
        logger.info("Stopping activity detection...")
        isDetecting = false
        detectionTask?.cancel()
        detectionTask = nil
        currentActivity = nil
    }
    
    // MARK: - Get Current State
    func getCurrentActivity() -> ActivitySnapshot? {
        return currentActivity
    }
    
    func getIsDetecting() -> Bool {
        return isDetecting
    }
    
    // MARK: - Activity Detection
    private func detectActivity() async {
        guard AccessibilityPermissionChecker.isAccessibilityGranted() else {
            logger.warning("Accessibility permissions not granted. Please grant permissions in System Settings.")
            return
        }
        
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return
        }
        
        // Check blacklist
        if let bundleId = frontmostApp.bundleIdentifier,
           blacklistedBundleIds.contains(bundleId) {
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
    
    // MARK: - Window Title Detection
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
    
    // MARK: - Idle Time Detection
    private func getIdleTime() -> TimeInterval {
        return CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .mouseMoved)
    }
    
    // MARK: - Activity Tag Mapping
    private func mapActivityTag(bundleId: String, appName: String, windowTitle: String) -> String {
        // Check custom rules first
        for rule in activityRules where rule.isEnabled {
            if appName.localizedCaseInsensitiveContains(rule.pattern) ||
               bundleId.localizedCaseInsensitiveContains(rule.pattern) ||
               windowTitle.localizedCaseInsensitiveContains(rule.pattern) {
                return rule.label
            }
        }
        
        // Default categorization
        return getDefaultActivityTag(bundleId: bundleId)
    }
    
    private func getDefaultActivityTag(bundleId: String) -> String {
        let developmentApps = [
            "com.apple.dt.Xcode",
            "com.microsoft.VSCode",
            "com.jetbrains.intellij",
            "com.jetbrains.pycharm",
            "com.github.atom",
            "com.sublimetext.3"
        ]
        
        let browserApps = [
            "com.apple.Safari",
            "com.google.Chrome",
            "org.mozilla.firefox",
            "com.microsoft.edgemac"
        ]
        
        let officeApps = [
            "com.microsoft.Word",
            "com.microsoft.Excel",
            "com.microsoft.PowerPoint",
            "com.apple.iWork.Pages",
            "com.apple.iWork.Numbers",
            "com.apple.iWork.Keynote"
        ]
        
        let communicationApps = [
            "com.tencent.xinWeChat",
            "com.tencent.qq",
            "com.microsoft.teams",
            "us.zoom.xos",
            "com.skype.skype"
        ]
        
        let entertainmentApps = [
            "com.apple.TV",
            "com.netflix.Netflix",
            "com.spotify.client",
            "com.apple.Music"
        ]
        
        if developmentApps.contains(bundleId) {
            return "开发"
        } else if browserApps.contains(bundleId) {
            return "浏览"
        } else if officeApps.contains(bundleId) {
            return "办公"
        } else if communicationApps.contains(bundleId) {
            return "沟通"
        } else if entertainmentApps.contains(bundleId) {
            return "娱乐"
        } else {
            return "其他"
        }
    }
}

