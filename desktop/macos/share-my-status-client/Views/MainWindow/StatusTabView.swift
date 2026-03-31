//
//  StatusTabView.swift
//  share-my-status-client
//


import SwiftUI

/// Status tab view showing current reporting status
struct StatusTabView: View {
    @EnvironmentObject var configuration: AppConfiguration
    @EnvironmentObject var reporter: StatusReporter
    @EnvironmentObject var coordinator: AppCoordinator
    
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed Title Bar with background
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.blue)
                    .imageScale(.large)
                Text("Share My Status")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Scrollable Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Reporting Status - Compact Layout
                GroupBox("上报状态") {
                    VStack(alignment: .leading, spacing: 6) {
                        // Main row: status + button + auto-reporting info
                        HStack(spacing: 12) {
                            StatusIndicator(
                                isActive: reporter.isReporting,
                                text: reporter.reportingStatus
                            )
                            
                            Spacer()
                            
                            // Info about automatic reporting (inline before button)
                            if reporter.isReporting {
                                HStack(spacing: 4) {
                                    Image(systemName: "info.circle")
                                        .font(.caption2)
                                    Text("自动上报中")
                                        .font(.caption2)
                                }
                                .foregroundColor(.secondary)
                            }
                            
                            Button(reporter.isReporting ? "停止上报" : "开始上报") {
                                if reporter.isReporting {
                                    reporter.stopReporting()
                                } else {
                                    reporter.startReporting()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        
                        // Error row (only shown when there's an error)
                        if let error = reporter.lastError {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                Text(error.localizedDescription)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
                
                GroupBox("软件更新") {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(coordinator.automaticallyChecksForUpdates ? "已启用自动检查" : "仅支持手动检查")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("更新检查与安装由 Sparkle 标准流程处理。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("检查更新…") {
                            coordinator.checkForUpdates()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!coordinator.canCheckForUpdates)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
                
                // Current Status
                GroupBox("当前状态") {
                    HStack(alignment: .top, spacing: 16) {
                        // Left side - Music Status (Vinyl Record Style) - natural height
                        VStack(spacing: 12) {
                            if let music = reporter.currentMusic {
                                ModernMusicCard(music: music)
                            } else if configuration.musicReportingEnabled {
                                EmptyMusicCard()
                            }
                            
                            // Activity Status below music
                            if let activity = reporter.currentActivity {
                                CompactActivityCard(activity: activity)
                            } else if configuration.activityReportingEnabled {
                                EmptyActivityCard()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Right side - System Status (Vertical Indicators) - stretch to match left height
                        if let system = reporter.currentSystem {
                            ModernSystemCard(system: system)
                                .frame(maxHeight: .infinity)
                        } else if configuration.systemReportingEnabled {
                            EmptySystemCard()
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Statistics
                GroupBox("统计信息") {
                    VStack(alignment: .leading, spacing: 8) {
                        StatisticsRow()
                    }
                    .padding(.vertical, 4)
                }
                
                    Spacer()
                }
                .padding()
            }
        }
    }
}

// Status Cards

/// Current music card
private struct CurrentMusicCard: View {
    let music: MusicSnapshot
    
    var body: some View {
        HStack(spacing: 12) {
            // Album artwork or default icon
            Group {
                if let nsImage = music.artworkImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 20))
                        .foregroundColor(.purple)
                        .frame(width: 48, height: 48)
                        .background(Color.purple.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(music.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    // Playing status indicator (small, non-interactive)
                    Circle()
                        .fill(music.isPlaying ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                }
                
                Text(music.artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if !music.album.isEmpty {
                    Text(music.album)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(10)
        .background(Color.purple.opacity(0.08))
        .cornerRadius(8)
    }
}

/// Current system card
private struct CurrentSystemCard: View {
    let system: SystemSnapshot
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                Text("系统状态")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                if let cpu = system.cpuPercentage {
                    SystemMetricView(
                        icon: "cpu",
                        label: "CPU",
                        value: "\(cpu)%",
                        color: .blue
                    )
                }
                
                if let memory = system.memoryPercentage {
                    SystemMetricView(
                        icon: "memorychip",
                        label: "内存",
                        value: "\(memory)%",
                        color: .orange
                    )
                }
                
                if let battery = system.batteryPercentage {
                    SystemMetricView(
                        icon: system.isCharging == true ? "battery.100.bolt" : "battery.100",
                        label: "电池",
                        value: "\(battery)%",
                        color: system.isCharging == true ? .green : .primary
                    )
                }
                
                Spacer()
            }
        }
        .padding(10)
        .background(Color.blue.opacity(0.08))
        .cornerRadius(8)
    }
}

/// System metric view
private struct SystemMetricView: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .imageScale(.small)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 50)
    }
}

/// Current activity card
private struct CurrentActivityCard: View {
    let activity: ActivitySnapshot
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.isIdle ? "moon.zzz.fill" : "person.crop.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(activity.isIdle ? .gray : .green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.activityTag)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(activity.activeApplication)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if activity.isIdle {
                    Text("空闲中")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding(10)
        .background((activity.isIdle ? Color.gray : Color.green).opacity(0.08))
        .cornerRadius(8)
    }
}

/// Empty state view
private struct EmptyStateView: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color.opacity(0.6))
                .imageScale(.medium)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(color.opacity(0.05))
        .cornerRadius(6)
    }
}

// Modern Music Card with Vinyl Record Style
private struct ModernMusicCard: View {
    let music: MusicSnapshot
    
    // Generate unique ID for each song to force view recreation when song changes
    private var musicID: String {
        music.title + music.artist + music.album
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Vinyl Record Style Album Art - wrapped in VinylRecordView
            VinylRecordView(music: music)
                .id(musicID) // Force recreation when song changes
            
            // Song info
            VStack(alignment: .leading, spacing: 8) {
                // Playing status
                HStack(spacing: 6) {
                    Image(systemName: music.isPlaying ? "play.fill" : "pause.fill")
                        .foregroundColor(music.isPlaying ? .green : .orange)
                        .font(.caption)
                    
                    Text(music.isPlaying ? "正在播放" : "已暂停")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Song title
                Text(music.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                // Artist
                Text(music.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Album
                if !music.album.isEmpty {
                    Text("专辑: \(music.album)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Duration indicator (if available)
                Text("1分钟前")
                    .font(.caption2)
                    .foregroundColor(Color.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

// Vinyl Record View - uses TimelineView for efficient rotation that pauses off-screen
private struct VinylRecordView: View {
    let music: MusicSnapshot
    
    // Track the accumulated angle so pausing/resuming is seamless
    @State private var baseAngle: Double = 0
    @State private var referenceDate: Date = .now
    
    private let rpm: Double = 120 // degrees per second (one revolution = 3 seconds)
    
    var body: some View {
        // TimelineView automatically pauses when the view is off-screen,
        // avoiding unnecessary rendering and energy usage.
        TimelineView(.animation(paused: !music.isPlaying)) { timeline in
            let elapsed = music.isPlaying
                ? timeline.date.timeIntervalSince(referenceDate)
                : 0
            let angle = baseAngle + elapsed * rpm
            
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 120, height: 120)
                
                Group {
                    if let nsImage = music.artworkImage {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(LinearGradient(
                                colors: [.purple.opacity(0.8), .purple.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                            )
                    }
                }
                
                Circle()
                    .fill(Color.black)
                    .frame(width: 20, height: 20)
                
                if music.isPlaying {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }
            }
            .rotationEffect(.degrees(angle))
        }
        .onChange(of: music.isPlaying) { isPlaying in
            if isPlaying {
                referenceDate = .now
            } else {
                // Freeze at current visual angle
                baseAngle = baseAngle + Date.now.timeIntervalSince(referenceDate) * rpm
                baseAngle = baseAngle.truncatingRemainder(dividingBy: 360)
            }
        }
    }
}

// Empty Music Card
private struct EmptyMusicCard: View {
    var body: some View {
        HStack(spacing: 16) {
            // Empty vinyl record
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                    )
                
                Circle()
                    .fill(Color.gray.opacity(0.7))
                    .frame(width: 20, height: 20)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("暂无音乐播放")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("当前没有检测到音乐播放")
                    .font(.caption)
                    .foregroundColor(Color.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }
}

// Modern System Card with Vertical Indicators
private struct ModernSystemCard: View {
    let system: SystemSnapshot
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "cpu.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("系统运行中")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("系统运行中")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                Spacer()
            }
            
            Spacer(minLength: 4)
            
            // Vertical Indicators
            VStack(spacing: 12) {
                // Battery
                if let battery = system.batteryPercentage {
                    ModernMetricRow(
                        icon: system.isCharging == true ? "bolt.fill" : "battery.100",
                        label: "电池",
                        value: battery,
                        unit: "%",
                        color: getBatteryColor(battery: battery, isCharging: system.isCharging == true),
                        isCharging: system.isCharging == true
                    )
                }
                
                // CPU
                if let cpu = system.cpuPercentage {
                    ModernMetricRow(
                        icon: "cpu",
                        label: "CPU",
                        value: cpu,
                        unit: "%",
                        color: getCPUColor(cpu: cpu)
                    )
                }
                
                // Memory
                if let memory = system.memoryPercentage {
                    ModernMetricRow(
                        icon: "memorychip",
                        label: "内存",
                        value: memory,
                        unit: "%",
                        color: getMemoryColor(memory: memory)
                    )
                }
            }
            
            Spacer(minLength: 4)
        }
        .padding(16)
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private func getBatteryColor(battery: Int, isCharging: Bool) -> Color {
        if isCharging { return .green }
        if battery > 50 { return .green }
        if battery > 20 { return .orange }
        return .red
    }
    
    private func getCPUColor(cpu: Int) -> Color {
        if cpu > 80 { return .red }
        if cpu > 60 { return .orange }
        return .blue
    }
    
    private func getMemoryColor(memory: Int) -> Color {
        if memory > 85 { return .red }
        if memory > 70 { return .orange }
        return .blue
    }
}

// Modern Metric Row
private struct ModernMetricRow: View {
    let icon: String
    let label: String
    let value: Int
    let unit: String
    let color: Color
    var isCharging: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
            }
            
            // Label and progress
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        Text("\(value)")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(unit)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if isCharging {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        Rectangle()
                            .fill(color)
                            .frame(width: geometry.size.width * CGFloat(value) / 100, height: 4)
                            .cornerRadius(2)
                            .animation(.easeInOut(duration: 0.3), value: value)
                    }
                }
                .frame(height: 4)
            }
        }
    }
}

// Empty System Card
private struct EmptySystemCard: View {
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.title2)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("系统监控")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("暂无数据")
                        .font(.caption)
                        .foregroundColor(Color.secondary)
                }
                
                Spacer()
            }
            
            Spacer(minLength: 4)
            
            VStack(spacing: 12) {
                EmptyMetricRow(icon: "battery.100", label: "电池")
                EmptyMetricRow(icon: "cpu", label: "CPU")
                EmptyMetricRow(icon: "memorychip", label: "内存")
            }
            
            Spacer(minLength: 4)
        }
        .padding(16)
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }
}

// Empty Metric Row
private struct EmptyMetricRow: View {
    let icon: String
    let label: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(Color.secondary)
                    
                    Spacer()
                    
                    Text("--")
                        .font(.caption)
                        .foregroundColor(Color.secondary)
                }
                
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 4)
                    .cornerRadius(2)
            }
        }
    }
}

// Compact Activity Card
private struct CompactActivityCard: View {
    let activity: ActivitySnapshot
    
    var body: some View {
        HStack(spacing: 12) {
            // Activity icon with background
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(activity.isIdle ? Color.gray.opacity(0.15) : Color.green.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: activity.isIdle ? "moon.zzz.fill" : "bolt.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(activity.isIdle ? .gray : .green)
            }
            
            // Activity info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(activity.activityTag)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Status indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(activity.isIdle ? .gray : .green)
                            .frame(width: 6, height: 6)
                        
                        Text(activity.isIdle ? "空闲中" : "活跃")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(activity.activeApplication)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Time indicator
                Text("2分钟前")
                    .font(.caption2)
                    .foregroundColor(Color.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
    }
}

// Empty Activity Card
private struct EmptyActivityCard: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("暂无活动数据")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("当前没有检测到用户活动")
                    .font(.caption)
                    .foregroundColor(Color.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }
}

// Statistics Row
private struct StatisticsRow: View {
    @EnvironmentObject var reporter: StatusReporter
    @State private var stats: (lastReportTime: Date?, reportCount: Int, isConnected: Bool) = (nil, 0, false)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("网络状态:")
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(stats.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(stats.isConnected ? "已连接" : "未连接")
                        .font(.caption)
                        .foregroundColor(stats.isConnected ? .green : .red)
                }
            }
            
            HStack {
                Text("上报次数:")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(stats.reportCount) 次")
                    .font(.caption)
            }
            
            if let lastTime = stats.lastReportTime {
                HStack {
                    Text("最后上报:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(lastTime, style: .time)
                        .font(.caption)
                }
            }
        }
        .font(.caption)
        .task {
            // Refresh every 5 seconds (stats rarely change; 1s was wasteful)
            while !Task.isCancelled {
                stats = await reporter.getNetworkStatistics()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }
}

#Preview {
    StatusTabView()
        .environmentObject(AppConfiguration())
        .environmentObject(StatusReporter())
        .frame(width: 600, height: 500)
}
