//
//  StatusTabView.swift
//  share-my-status-client
//
//  Created by Refactor on 2025-01-07.
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
                            
                            Button("立即上报") {
                                Task {
                                    await reporter.performReport()
                                }
                            }
                            .disabled(!reporter.isReporting)
                            
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Current Status
                GroupBox("当前状态") {
                    ScrollView {
                        Text(reporter.getStatusSummary())
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 5)
                    }
                    .frame(height: 140)
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

// MARK: - Statistics Row
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

