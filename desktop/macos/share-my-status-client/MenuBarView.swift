//
//  MenuBarView.swift
//  share-my-status-client
//

import SwiftUI

/// Menu bar view (compatible with macOS 13.0+)
struct MenuBarView: View {
    @EnvironmentObject var configuration: AppConfiguration
    @EnvironmentObject var reporter: StatusReporter
    @EnvironmentObject var coordinator: AppCoordinator
    
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
            
            // Update banner prompt in menu bar
            if let latest = coordinator.availableUpdate {
                MenuBarUpdateBanner(latest: latest)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            
            // Permission Warning
            if configuration.activityReportingEnabled && !AccessibilityPermissionChecker.isAccessibilityGranted() {
                Button(action: {
                    AccessibilityPermissionChecker.openAccessibilitySettings()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .frame(width: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("需要辅助功能权限")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                            Text("点击查看详细设置步骤")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
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
                    HStack(spacing: 8) {
                        // Album artwork or default icon
                        Group {
                            if let artworkData = music.artworkData,
                               let nsImage = NSImage(data: artworkData) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 28, height: 28)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            } else {
                                Image(systemName: "music.note")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                                    .frame(width: 28, height: 28)
                                    .background(Color.purple.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(music.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                Circle()
                                    .fill(music.isPlaying ? Color.green : Color.orange)
                                    .frame(width: 4, height: 4)
                            }
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
                    HStack(spacing: 10) {
                        if let battery = system.batteryPercentage {
                            HStack(spacing: 4) {
                                Image(systemName: system.isCharging == true ? "battery.100.bolt" : "battery.100")
                                    .foregroundColor(system.isCharging == true ? .green : .primary)
                                    .frame(width: 14)
                                Text("\(battery)%")
                                    .font(.caption2)
                            }
                        }
                        
                        if let cpu = system.cpuPercentage {
                            HStack(spacing: 4) {
                                Image(systemName: "cpu")
                                    .foregroundColor(.blue)
                                    .frame(width: 14)
                                Text("\(cpu)%")
                                    .font(.caption2)
                            }
                        }
                        
                        if let memory = system.memoryPercentage {
                            HStack(spacing: 4) {
                                Image(systemName: "memorychip")
                                    .foregroundColor(.orange)
                                    .frame(width: 14)
                                Text("\(memory)%")
                                    .font(.caption2)
                            }
                        }
                        
                        Spacer()
                    }
                }
                
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
    
    private func openMainWindow() {
        // Try open by window id first
        if #available(macOS 13.0, *) {
            openWindow(id: "main")
        } else {
            createMainWindowManually()
        }
    }
    
    private func createMainWindowManually() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Share My Status"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: ContentView()
            .environmentObject(configuration)
            .environmentObject(reporter)
            .environmentObject(coordinator)
        )
        window.makeKeyAndOrderFront(nil)
        
        // Keep regular app appearance when main window is open
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        setupWindowCloseHandler(window)
    }
    
    private func setupWindowCloseHandler(_ window: NSWindow) {
        let delegate = WindowCloseDelegate()
        window.delegate = delegate
    }
}

private struct MenuBarUpdateBanner: View {
    let latest: ClientVersionInfo
    var versionText: String { latest.version ?? "未知版本" }
    var buildText: String { latest.buildNumber != nil ? String(latest.buildNumber!) : "未知构建" }
    var isForce: Bool { latest.forceUpdate ?? false }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isForce ? "exclamationmark.triangle.fill" : "arrow.down.circle")
                .foregroundColor(isForce ? .orange : .blue)
                .frame(width: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(isForce ? "强制更新可用" : "有新版本可用")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("\(versionText) (\(buildText))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                // 新增：下载链接文本，点击打开浏览器
                if let urlStr = latest.downloadUrl, let url = URL(string: urlStr) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Link("打开下载页面", destination: url)
                            .font(.caption2)
                    }
                }
            }
            Spacer()
            if let urlStr = latest.downloadUrl, let url = URL(string: urlStr) {
                Button(isForce ? "更新" : "下载") {
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(8)
        .background((isForce ? Color.orange : Color.blue).opacity(0.08))
        .cornerRadius(6)
    }
}

// Window Close Delegate

/// Delegate to handle window close events
class WindowCloseDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // When window closes, switch back to accessory mode (hide from Dock)
        DispatchQueue.main.async {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }
}

// Custom Button Style

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
