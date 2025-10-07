//
//  AccessibilityPermissionChecker.swift
//  share-my-status-client
//
//  Created on 2025-01-07.
//

import Foundation
import ApplicationServices
import AppKit

/// Helper for checking and requesting Accessibility permissions
class AccessibilityPermissionChecker {
    /// Check if accessibility permissions are granted
    static func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }
    
    /// Request accessibility permissions (shows system prompt)
    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    /// Open System Settings to Accessibility preferences
    static func openAccessibilitySettings() {
        // Open System Settings > Privacy & Security > Accessibility
        // macOS Ventura and later
        if #available(macOS 13.0, *) {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        } else {
            // Older macOS versions
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Get user-friendly permission status message
    static func getPermissionStatusMessage() -> String {
        if isAccessibilityGranted() {
            return "已授权 ✓"
        } else {
            return "需要授权"
        }
    }
    
    /// Get detailed permission help message
    static func getHelpMessage() -> String {
        return """
        活动检测功能需要辅助功能权限才能获取前台应用信息和窗口标题。
        
        授权步骤：
        1. 点击"打开系统设置"按钮
        2. 在"隐私与安全性"中找到"辅助功能"
        3. 添加并勾选 "share-my-status-client"
        4. 重新启动应用以使权限生效
        """
    }
}

