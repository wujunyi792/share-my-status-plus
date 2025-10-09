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
    
    /// Open System Settings to Accessibility preferences and show detailed instructions
    static func openAccessibilitySettings() {
        // Show instruction dialog first
        showAccessibilityInstructionDialog()
    }
    
    /// Show detailed instruction dialog for adding the app to Accessibility list
    private static func showAccessibilityInstructionDialog() {
        let alert = NSAlert()
        alert.messageText = "辅助功能权限设置"
        alert.informativeText = """
        活动检测需要辅助功能权限。请按照以下步骤操作：
        
        1. 点击"打开系统设置"按钮
        2. 在"隐私与安全性"中找到"辅助功能"
        3. 点击"+"按钮，会弹出文件选择器
        4. 在文件选择器中前往"应用程序"文件夹
        5. 找到并选择"Share My Status"应用
        6. 点击"打开"按钮添加应用
        7. 确保应用旁边的复选框已勾选
        8. 返回本应用点击刷新按钮验证权限
        
        提示：应用通常位于 /Applications（应用程序）文件夹
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后设置")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openSettingsPage()
        }
    }
    
    /// Open the actual settings page
    private static func openSettingsPage() {
        // Open System Settings/Preferences > Privacy & Security > Accessibility
        // Note: URL scheme works for both old System Preferences and new Settings app
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
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
        3. 点击左下角的锁图标解锁（输入密码）
        4. 点击"+"按钮打开文件选择器
        5. 在"应用程序"文件夹中找到"Share My Status"
        6. 选择应用并点击"打开"
        7. 确保应用旁边的复选框已勾选
        8. 返回应用点击刷新按钮验证
        """
    }
    
    /// Get the app bundle path for user reference
    static func getAppPath() -> String {
        return Bundle.main.bundlePath
    }
}

