//
//  SettingsTabView.swift
//  share-my-status-client
//
//  Created by Refactor on 2025-01-07.
//

import SwiftUI

/// Settings tab view for app configuration
struct SettingsTabView: View {
    @EnvironmentObject var configuration: AppConfiguration
    @State private var accessibilityGranted = AccessibilityPermissionChecker.isAccessibilityGranted()
    @State private var showAccessibilityHelp = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Permissions Status
                GroupBox("权限状态") {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("辅助功能权限")
                                    .font(.headline)
                                Text("活动检测需要此权限")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(accessibilityGranted ? .green : .red)
                                Text(accessibilityGranted ? "已授权" : "未授权")
                                    .font(.caption)
                                    .foregroundColor(accessibilityGranted ? .green : .red)
                            }
                        }
                        
                        if !accessibilityGranted {
                            VStack(spacing: 10) {
                                Button("打开系统设置") {
                                    AccessibilityPermissionChecker.openAccessibilitySettings()
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Text("请在系统设置中授予辅助功能权限，然后重启应用")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 5)
                        }
                        
                        Button(action: {
                            accessibilityGranted = AccessibilityPermissionChecker.isAccessibilityGranted()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("刷新状态")
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                }
                
                // Network Settings
                GroupBox("网络设置") {
                    VStack(alignment: .leading, spacing: 15) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("服务器地址")
                                .font(.headline)
                            TextField(DefaultSettings.endpointURL, text: $configuration.endpointURL)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("密钥")
                                .font(.headline)
                            SecureField("输入API密钥", text: $configuration.secretKey)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                
                // Feature Settings
                GroupBox("功能设置") {
                    VStack(alignment: .leading, spacing: 15) {
                        Toggle("启用状态上报", isOn: $configuration.isReportingEnabled)
                            .font(.headline)
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 15) {
                            // Music Reporting
                            Toggle("音乐信息上报 (事件驱动)", isOn: $configuration.musicReportingEnabled)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("音乐播放状态变化时立即上报")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)
                            
                            Divider()
                            
                            // System Monitoring
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle("系统指标上报 (轮询)", isOn: $configuration.systemReportingEnabled)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if configuration.systemReportingEnabled {
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack {
                                            Text("轮询间隔:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                        }
                                        HStack {
                                            Slider(
                                                value: Binding(
                                                    get: { Double(configuration.systemPollingInterval) },
                                                    set: { configuration.systemPollingInterval = TimeInterval($0) }
                                                ),
                                                in: DefaultSettings.systemPollingIntervalRange,
                                                step: DefaultSettings.systemPollingIntervalStep
                                            )
                                            Text("\(Int(configuration.systemPollingInterval))秒")
                                                .font(.caption)
                                                .frame(width: 40)
                                        }
                                    }
                                    .padding(.leading, 20)
                                }
                            }
                            
                            Divider()
                            
                            // Activity Detection
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle("活动检测上报 (轮询)", isOn: $configuration.activityReportingEnabled)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if configuration.activityReportingEnabled {
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack {
                                            Text("轮询间隔:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                        }
                                        HStack {
                                            Slider(
                                                value: Binding(
                                                    get: { Double(configuration.activityPollingInterval) },
                                                    set: { configuration.activityPollingInterval = TimeInterval($0) }
                                                ),
                                                in: DefaultSettings.activityPollingIntervalRange,
                                                step: DefaultSettings.activityPollingIntervalStep
                                            )
                                            Text("\(Int(configuration.activityPollingInterval))秒")
                                                .font(.caption)
                                                .frame(width: 40)
                                        }
                                    }
                                    .padding(.leading, 20)
                                }
                            }
                        }
                        .disabled(!configuration.isReportingEnabled)
                    }
                }
                
                // Music Settings
                if configuration.musicReportingEnabled {
                    GroupBox("音乐设置") {
                        AppListEditor(
                            title: "应用白名单",
                            apps: $configuration.musicAppWhitelist,
                            mode: .whitelist,
                            defaultApps: DefaultSettings.musicAppWhitelist
                        )
                    }
                }
                
                // Activity Settings
                if configuration.activityReportingEnabled {
                    GroupBox("活动设置") {
                        ActivityGroupEditor(groups: $configuration.activityGroups)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - App List Editor Component
private struct AppListEditor: View {
    let title: String
    @Binding var apps: [String]
    let mode: AppPickerView.AppPickerMode
    let defaultApps: [String]
    
    @State private var showingAppPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                Button("恢复默认") {
                    apps = defaultApps
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                
                Button("从应用选择") {
                    showingAppPicker = true
                }
                .buttonStyle(.borderedProminent)
            }
            
            if apps.isEmpty {
                Text("暂无应用")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(Array(apps.enumerated()), id: \.offset) { index, app in
                    HStack {
                        Text(app)
                            .font(.system(.body, design: .monospaced))
                        
                        Spacer()
                        
                        Button(action: {
                            apps.remove(at: index)
                        }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            Button(action: {
                apps.append("")
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("手动添加")
                }
            }
            .buttonStyle(.borderless)
        }
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView(
                selectedApps: $apps,
                title: "选择要\(mode == .whitelist ? "添加到白名单" : "添加到黑名单")的应用",
                mode: mode
            )
        }
    }
}

#Preview {
    SettingsTabView()
        .environmentObject(AppConfiguration())
        .frame(width: 600, height: 500)
}

