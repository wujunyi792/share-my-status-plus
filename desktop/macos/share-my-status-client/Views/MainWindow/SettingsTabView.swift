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
                            TextField("https://api.example.com/v1/state/report", text: $configuration.endpointURL)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("密钥")
                                .font(.headline)
                            SecureField("输入API密钥", text: $configuration.secretKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("上报间隔")
                                .font(.headline)
                            HStack {
                                Slider(
                                    value: Binding(
                                        get: { Double(configuration.reportInterval) },
                                        set: { configuration.reportInterval = TimeInterval($0) }
                                    ),
                                    in: 10...300,
                                    step: 10
                                )
                                Text("\(Int(configuration.reportInterval))秒")
                                    .frame(width: 50)
                            }
                        }
                    }
                }
                
                // Feature Settings
                GroupBox("功能设置") {
                    VStack(alignment: .leading, spacing: 15) {
                        Toggle("启用状态上报", isOn: $configuration.isReportingEnabled)
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("音乐信息上报", isOn: $configuration.musicReportingEnabled)
                            Toggle("系统指标上报", isOn: $configuration.systemReportingEnabled)
                            Toggle("活动检测上报", isOn: $configuration.activityReportingEnabled)
                        }
                        .disabled(!configuration.isReportingEnabled)
                    }
                }
                
                // Music Settings
                if configuration.musicReportingEnabled {
                    GroupBox("音乐设置") {
                        AppWhitelistEditor(
                            title: "应用白名单",
                            apps: $configuration.musicAppWhitelist
                        )
                    }
                }
                
                // Activity Settings
                if configuration.activityReportingEnabled {
                    GroupBox("活动设置") {
                        AppWhitelistEditor(
                            title: "应用黑名单",
                            apps: $configuration.activityAppBlacklist
                        )
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - App Whitelist Editor Component
private struct AppWhitelistEditor: View {
    let title: String
    @Binding var apps: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            
            ForEach(Array(apps.enumerated()), id: \.offset) { index, app in
                HStack {
                    TextField("应用Bundle ID", text: Binding(
                        get: { app },
                        set: { newValue in
                            apps[index] = newValue
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    
                    Button(action: {
                        apps.remove(at: index)
                    }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                }
            }
            
            Button(action: {
                apps.append("")
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("添加应用")
                }
            }
            .buttonStyle(.borderless)
        }
    }
}

#Preview {
    SettingsTabView()
        .environmentObject(AppConfiguration())
        .frame(width: 600, height: 500)
}

