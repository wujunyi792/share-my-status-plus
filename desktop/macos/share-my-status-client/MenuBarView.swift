//
//  MenuBarView.swift
//  share-my-status-client
//
//  Refactored on 2025-01-07.
//

import SwiftUI

/// Menu bar view (compatible with macOS 13.0+)
struct MenuBarView: View {
    @EnvironmentObject var configuration: AppConfiguration
    @EnvironmentObject var reporter: StatusReporter
    
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.blue)
                Text("Share My Status")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Permission Warning
            if configuration.activityReportingEnabled && !AccessibilityPermissionChecker.isAccessibilityGranted() {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .frame(width: 12)
                    Text("需要辅助功能权限")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
            }
            
            // Status Information
            VStack(alignment: .leading, spacing: 8) {
                // Reporting Status
                StatusIndicator(
                    isActive: reporter.isReporting,
                    text: reporter.reportingStatus
                )
                
                // Current Music
                if let music = reporter.currentMusic {
                    HStack(spacing: 6) {
                        Image(systemName: "music.note")
                            .foregroundColor(.purple)
                            .frame(width: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(music.title)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text(music.artist)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                }
                
                // System Status
                if let system = reporter.currentSystem {
                    HStack(spacing: 8) {
                        if let battery = system.batteryPercentage {
                            HStack(spacing: 2) {
                                Image(systemName: system.isCharging == true ? "battery.100.bolt" : "battery.100")
                                    .foregroundColor(system.isCharging == true ? .green : .primary)
                                    .frame(width: 12)
                                Text("\(battery)%")
                                    .font(.caption2)
                            }
                        }
                        
                        if let cpu = system.cpuPercentage {
                            HStack(spacing: 2) {
                                Image(systemName: "cpu")
                                    .foregroundColor(.blue)
                                    .frame(width: 12)
                                Text("\(cpu)%")
                                    .font(.caption2)
                            }
                        }
                        
                        if let memory = system.memoryPercentage {
                            HStack(spacing: 2) {
                                Image(systemName: "memorychip")
                                    .foregroundColor(.orange)
                                    .frame(width: 12)
                                Text("\(memory)%")
                                    .font(.caption2)
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                // Current Activity
                if let activity = reporter.currentActivity {
                    HStack(spacing: 6) {
                        Image(systemName: activity.isIdle ? "moon.zzz" : "person.crop.circle")
                            .foregroundColor(activity.isIdle ? .gray : .green)
                            .frame(width: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.activityTag)
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(activity.activeApplication)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Action Buttons
            VStack(spacing: 0) {
                Button(action: {
                    if reporter.isReporting {
                        reporter.stopReporting()
                    } else {
                        reporter.startReporting()
                    }
                }) {
                    HStack {
                        Image(systemName: reporter.isReporting ? "stop.circle" : "play.circle")
                        Text(reporter.isReporting ? "停止上报" : "开始上报")
                        Spacer()
                    }
                    .contentShape(Rectangle())  // Make entire area clickable
                }
                .buttonStyle(MenuBarButtonStyle())
                
                Button(action: {
                    openMainWindow()
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("设置")
                        Spacer()
                    }
                    .contentShape(Rectangle())  // Make entire area clickable
                }
                .buttonStyle(MenuBarButtonStyle())
                
                Divider()
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack {
                        Image(systemName: "power")
                        Text("退出")
                        Spacer()
                    }
                    .contentShape(Rectangle())  // Make entire area clickable
                }
                .buttonStyle(MenuBarButtonStyle())
            }
        }
        .frame(width: 280)
    }
    
    // MARK: - Helper Methods
    private func openMainWindow() {
        // Find existing main window (exclude status bar and panels)
        let existingWindow = NSApplication.shared.windows.first { window in
            // Exclude NSPanel (status bar popup)
            guard !window.isKind(of: NSPanel.self) else { return false }
            
            // Exclude NSStatusBarWindow explicitly
            let className = NSStringFromClass(type(of: window))
            guard !className.contains("StatusBar") else { return false }
            
            // Must have content and be regular window
            return window.contentView != nil && window.canBecomeKey
        }
        
        if let window = existingWindow {
            // Found existing window, bring it to front
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else {
            // No existing window, create new one
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
            
            if #available(macOS 14.0, *) {
                openWindow(id: "main")
            } else {
                // Fallback for macOS 13.x
                createMainWindowManually()
            }
        }
    }
    
    /// Manually create main window for macOS 13.x
    private func createMainWindowManually() {
        let contentView = ContentView()
            .environmentObject(configuration)
            .environmentObject(reporter)
        
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Share My Status"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 600, height: 500))
        window.center()
        
        // Setup window close handler to hide from Dock
        setupWindowCloseHandler(window)
        
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    /// Setup window close handler to switch back to accessory mode
    private func setupWindowCloseHandler(_ window: NSWindow) {
        // Use NSWindowDelegate to handle window close
        let delegate = WindowCloseDelegate()
        window.delegate = delegate
        
        // Store delegate to prevent deallocation
        objc_setAssociatedObject(window, "closeDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)
    }
}

// MARK: - Window Close Delegate

/// Delegate to handle window close events
class WindowCloseDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // When window closes, switch back to accessory mode (hide from Dock)
        DispatchQueue.main.async {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }
}

// MARK: - Custom Button Style

/// Custom button style for menu bar items with hover effect
struct MenuBarButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)  // Full width clickable
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                configuration.isPressed ? Color.accentColor.opacity(0.2) :
                (isHovered ? Color.gray.opacity(0.15) : Color.clear)
            )
            .cornerRadius(4)
            .contentShape(Rectangle())  // Ensure entire area is interactive
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AppConfiguration())
        .environmentObject(StatusReporter())
}