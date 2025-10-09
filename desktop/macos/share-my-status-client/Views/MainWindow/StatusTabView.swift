//
//  StatusTabView.swift
//  share-my-status-client
//


import SwiftUI

/// Status tab view showing current reporting status
struct StatusTabView: View {
    @EnvironmentObject var configuration: AppConfiguration
    @EnvironmentObject var reporter: StatusReporter
    
    @State private var isTestingConnection = false
    @State private var connectionTestResult: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.blue)
                        .imageScale(.large)
                    Text("Share My Status")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                }
                
                // Reporting Status
                GroupBox("上报状态") {
                    VStack(alignment: .leading, spacing: 12) {
                        StatusIndicator(
                            isActive: reporter.isReporting,
                            text: reporter.reportingStatus
                        )
                        
                        if let error = reporter.lastError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text(error.localizedDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Button(reporter.isReporting ? "停止上报" : "开始上报") {
                                if reporter.isReporting {
                                    reporter.stopReporting()
                                } else {
                                    reporter.startReporting()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Spacer()
                            
                            // Info about automatic reporting
                            if reporter.isReporting {
                                HStack(spacing: 4) {
                                    Image(systemName: "info.circle")
                                        .font(.caption)
                                    Text("自动上报中")
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Current Status
                GroupBox("当前状态") {
                    VStack(spacing: 12) {
                        // Music Status
                        if let music = reporter.currentMusic {
                            CurrentMusicCard(music: music)
                        } else if configuration.musicReportingEnabled {
                            EmptyStateView(
                                icon: "music.note",
                                text: "暂无音乐播放",
                                color: .purple
                            )
                        }
                        
                        // System Status
                        if let system = reporter.currentSystem {
                            CurrentSystemCard(system: system)
                        } else if configuration.systemReportingEnabled {
                            EmptyStateView(
                                icon: "cpu",
                                text: "暂无系统数据",
                                color: .blue
                            )
                        }
                        
                        // Activity Status
                        if let activity = reporter.currentActivity {
                            CurrentActivityCard(activity: activity)
                        } else if configuration.activityReportingEnabled {
                            EmptyStateView(
                                icon: "person.crop.circle",
                                text: "暂无活动数据",
                                color: .green
                            )
                        }
                        
                        // No data at all
                        if !configuration.musicReportingEnabled 
                            && !configuration.systemReportingEnabled 
                            && !configuration.activityReportingEnabled {
                            EmptyStateView(
                                icon: "rectangle.3.group",
                                text: "请在设置中启用功能",
                                color: .orange
                            )
                        }
                    }
                    .padding(.vertical, 4)
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

// Status Cards

/// Current music card
private struct CurrentMusicCard: View {
    let music: MusicSnapshot
    
    var body: some View {
        HStack(spacing: 12) {
            // Album artwork or default icon
            Group {
                if let artworkData = music.artworkData,
                   let nsImage = NSImage(data: artworkData) {
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
                ConnectionStatusView(isConnected: stats.isConnected)
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
            // Update stats periodically
            while !Task.isCancelled {
                stats = await reporter.getNetworkStatistics()
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
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

