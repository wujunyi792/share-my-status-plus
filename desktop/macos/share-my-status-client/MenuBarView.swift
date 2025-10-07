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
            VStack(spacing: 4) {
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
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                
                Button(action: {
                    Task {
                        await reporter.performReport()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.up.circle")
                        Text("立即上报")
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .disabled(!reporter.isReporting)
                
                Button(action: {
                    openMainWindow()
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("设置")
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                
                Divider()
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack {
                        Image(systemName: "power")
                        Text("退出")
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
        }
        .frame(width: 280)
    }
    
    // MARK: - Helper Methods
    private func openMainWindow() {
        // Check if main window already exists
        if let existingWindow = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.orderFrontRegardless()
        } else {
            // Create new window
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
            if #available(macOS 14.0, *) {
                openWindow(id: "main")
            }
        }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AppConfiguration())
        .environmentObject(StatusReporter())
}