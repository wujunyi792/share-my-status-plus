//
//  SettingsTabView.swift
//  share-my-status-client
//


import SwiftUI
import UniformTypeIdentifiers

/// Settings tab view for app configuration
struct SettingsTabView: View {
    @EnvironmentObject var configuration: AppConfiguration
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var accessibilityGranted = AccessibilityPermissionChecker.isAccessibilityGranted()
    @State private var showAccessibilityHelp = false
    
    // Import/Export states
    @State private var showExportOptions = false
    @State private var includeSecretKeyInExport = false
    @State private var showExportSuccess = false
    @State private var showImportDialog = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var showImportSuccess = false
    @State private var importJSONText = ""
    @State private var showValidationError = false
    @State private var validationErrorMessage = ""
    
    // Secret key visibility
    @State private var isSecretKeyVisible = false
    
    // Link customization
    @State private var showLinkCustomizer = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed Title Bar with background
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(.blue)
                    .imageScale(.large)
                Text("设置")
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
                    // Permissions Status - Compact Layout
                    GroupBox("权限状态") {
                    VStack(alignment: .leading, spacing: 6) {
                        // Main row: title + status + refresh button
                        HStack(spacing: 12) {
                            HStack(spacing: 6) {
                                Text("辅助功能")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("活动检测")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Status indicator
                            HStack(spacing: 6) {
                                Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(accessibilityGranted ? .green : .red)
                                    .imageScale(.small)
                                Text(accessibilityGranted ? "已授权" : "未授权")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(accessibilityGranted ? .green : .red)
                            }
                            
                            // Refresh button
                            Button(action: {
                                accessibilityGranted = AccessibilityPermissionChecker.isAccessibilityGranted()
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .imageScale(.small)
                            }
                            .buttonStyle(.borderless)
                            .help("刷新权限状态")
                            
                            // Settings button (when not granted)
                            if !accessibilityGranted {
                                Button(action: {
                                    AccessibilityPermissionChecker.openAccessibilitySettings()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "gearshape.fill")
                                            .imageScale(.small)
                                        Text("打开设置")
                                            .font(.caption2)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.mini)
                            }
                        }
                        
                        // Compact hint (only when not granted)
                        if !accessibilityGranted {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                Text("需在系统设置中手动添加应用到辅助功能列表")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
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
                            HStack(spacing: 8) {
                                if isSecretKeyVisible {
                                    TextField("输入API密钥", text: $configuration.secretKey)
                                        .textFieldStyle(.roundedBorder)
                                } else {
                                    SecureField("输入API密钥", text: $configuration.secretKey)
                                        .textFieldStyle(.roundedBorder)
                                }
                                
                                Button(action: {
                                    isSecretKeyVisible.toggle()
                                }) {
                                    Image(systemName: isSecretKeyVisible ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.secondary)
                                        .frame(width: 20, height: 20)
                                }
                                .buttonStyle(.borderless)
                                .help(isSecretKeyVisible ? "隐藏密钥" : "显示密钥")
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
                
                // Feature Settings
                GroupBox("功能设置") {
                    VStack(alignment: .leading, spacing: 15) {
                        // Music Reporting
                        Toggle("音乐信息上报", isOn: $configuration.musicReportingEnabled)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            
                            Divider()
                            
                            // System Monitoring
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle("系统指标上报", isOn: $configuration.systemReportingEnabled)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if configuration.systemReportingEnabled {
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack {
                                            Text("更新频率:")
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
                                            Text("每 \(Int(configuration.systemPollingInterval)) 秒")
                                                .font(.caption)
                                                .frame(width: 60)
                                        }
                                    }
                                    .padding(.leading, 20)
                                }
                            }
                            
                            Divider()
                            
                            // Activity Detection
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle("活动检测上报", isOn: $configuration.activityReportingEnabled)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if configuration.activityReportingEnabled {
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack {
                                            Text("检测频率:")
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
                                            Text("每 \(Int(configuration.activityPollingInterval)) 秒")
                                                .font(.caption)
                                                .frame(width: 60)
                                        }
                                    }
                                .padding(.leading, 20)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
                
                // 更新检查已默认开启；如有更新将在状态页与菜单栏提示                
                // Music Settings
                if configuration.musicReportingEnabled {
                    GroupBox("音乐设置") {
                        AppListEditor(
                            title: "应用白名单",
                            apps: $configuration.musicAppWhitelist,
                            mode: .whitelist,
                            defaultApps: DefaultSettings.musicAppWhitelist
                        )
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                    }
                }
                
                // Activity Settings
                if configuration.activityReportingEnabled {
                    GroupBox("活动设置") {
                        ActivityGroupEditor(groups: $configuration.activityGroups)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                    }
                }
                
                // Link Customization
                GroupBox("链接定制") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("创建自定义飞书签名链接，展示实时状态信息")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            showLinkCustomizer = true
                        }) {
                            HStack {
                                Image(systemName: "link.badge.plus")
                                Text("打开链接定制工具")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .imageScale(.small)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showLinkCustomizer) {
                            CustomLinkView()
                                .frame(width: 700, height: 800)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
                
                // Import/Export Settings
                GroupBox("配置管理") {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("导入或导出当前配置，便于备份或在多台设备间同步设置")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            // Export Button
                            Button(action: {
                                showExportOptions = true
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("导出配置")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .sheet(isPresented: $showExportOptions) {
                                ExportOptionsView(
                                    includeSecretKey: $includeSecretKeyInExport,
                                    onExportToClipboard: {
                                        let success = configuration.exportToClipboard(includeSecretKey: includeSecretKeyInExport)
                                        showExportOptions = false
                                        if success {
                                            showExportSuccess = true
                                        }
                                    },
                                    onExportToFile: {
                                        showExportOptions = false
                                        saveConfigurationFile()
                                    },
                                    onCancel: {
                                        showExportOptions = false
                                    }
                                )
                            }
                            
                            // Import Button
                            Button(action: {
                                showImportDialog = true
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("导入配置")
                                }
                            }
                            .buttonStyle(.bordered)
                            .sheet(isPresented: $showImportDialog) {
                                ImportDialogView(
                                    jsonText: $importJSONText,
                                    showValidationError: $showValidationError,
                                    validationErrorMessage: $validationErrorMessage,
                                    showImportError: $showImportError,
                                    importErrorMessage: $importErrorMessage,
                                    onImportFromFile: {
                                        showImportDialog = false
                                        openConfigurationFile()
                                    },
                                    onImportManual: { jsonText in
                                        // Validate first
                                        let validation = configuration.validateConfigurationJSON(jsonText)
                                        if validation.isValid {
                                            if let error = configuration.importFromJSON(jsonText) {
                                                importErrorMessage = error
                                                showImportError = true
                                            } else {
                                                showImportDialog = false
                                                showImportSuccess = true
                                                importJSONText = ""
                                            }
                                        } else {
                                            validationErrorMessage = validation.errorMessage ?? "未知错误"
                                            showValidationError = true
                                        }
                                    },
                                    onCancel: {
                                        showImportDialog = false
                                        importJSONText = ""
                                    }
                                )
                            }
                        }
                        
                        // Success/Error messages
                        if showExportSuccess {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("配置已复制到剪贴板")
                                    .font(.caption)
                                Spacer()
                            }
                            .padding(8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                    withAnimation { showExportSuccess = false }
                                }
                            }
                        }
                        
                        if showImportSuccess {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("配置导入成功")
                                    .font(.caption)
                                Spacer()
                            }
                            .padding(8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                    withAnimation { showImportSuccess = false }
                                }
                            }
                        }
                        
                        if showImportError && !showImportDialog {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("导入失败")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text(importErrorMessage)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("关闭") {
                                    showImportError = false
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                            }
                            .padding(8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                        }
                        
                        if showValidationError && !showImportDialog {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("格式校验失败")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text(validationErrorMessage)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("关闭") {
                                    showValidationError = false
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                            }
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
                
                // App Information
                GroupBox("应用信息") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("应用版本")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("构建版本")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "未知")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("自动更新")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            updateStatusLabel
                            Button("检查更新") {
                                coordinator.checkForUpdates()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(!coordinator.canCheckForUpdates)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("应用标识符")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            HStack {
                                Text(Bundle.main.bundleIdentifier ?? "未知")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    if let bundleId = Bundle.main.bundleIdentifier {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(bundleId, forType: .string)
                                    }
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .imageScale(.small)
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(.blue)
                                .help("复制到剪贴板")
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
                
                    Spacer()
                }
                .padding()
            }
        }
    }
    
    // File Operations
    
    /// Save configuration to file
    private func saveConfigurationFile() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "share-my-status-config.json"
        savePanel.message = "选择保存位置"
        savePanel.prompt = "保存"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                if let error = configuration.exportToFile(url: url, includeSecretKey: includeSecretKeyInExport) {
                    importErrorMessage = error
                    showImportError = true
                } else {
                    showExportSuccess = true
                }
            }
        }
    }
    
    @ViewBuilder
    private var updateStatusLabel: some View {
        if coordinator.automaticallyChecksForUpdates {
            Text("已启用自动检查")
                .font(.caption)
                .foregroundColor(.green)
        } else {
            Text("仅支持手动检查")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    /// Open configuration file
    private func openConfigurationFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.message = "选择配置文件"
        openPanel.prompt = "打开"
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                if let error = configuration.importFromFile(url: url) {
                    importErrorMessage = error
                    showImportError = true
                } else {
                    showImportSuccess = true
                }
            }
        }
    }
}

// App List Editor Component
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

// Export Options View

/// Export options dialog
private struct ExportOptionsView: View {
    @Binding var includeSecretKey: Bool
    let onExportToClipboard: () -> Void
    let onExportToFile: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("导出配置")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("将当前配置导出为 JSON 格式")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Options
            VStack(alignment: .leading, spacing: 12) {
                Text("导出选项")
                    .font(.headline)
                
                Toggle(isOn: $includeSecretKey) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("包含密钥 (Secret Key)")
                            .font(.subheadline)
                        Text("如果导出的配置将在不安全的环境中传输或存储，建议不要包含密钥")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
                
                if includeSecretKey {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("警告：导出的配置将包含敏感信息，请妥善保管")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            Divider()
            
            // Action Buttons
            HStack {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(action: onExportToFile) {
                    HStack {
                        Image(systemName: "doc.badge.arrow.up")
                        Text("导出为文件")
                    }
                }
                .buttonStyle(.bordered)
                
                Button(action: onExportToClipboard) {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                        Text("导出到剪贴板")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 550)
    }
}

// Import Dialog View

/// Import configuration dialog
private struct ImportDialogView: View {
    @Binding var jsonText: String
    @Binding var showValidationError: Bool
    @Binding var validationErrorMessage: String
    @Binding var showImportError: Bool
    @Binding var importErrorMessage: String
    let onImportFromFile: () -> Void
    let onImportManual: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "square.and.arrow.down.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("导入配置")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("从文件或手动输入导入配置")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Manual input only
            VStack(alignment: .leading, spacing: 12) {
                ManualImportView(jsonText: $jsonText)

                // Inline error messages below the TextEditor
                if showValidationError {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("格式校验失败")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(validationErrorMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("关闭") {
                            showValidationError = false
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }

                if showImportError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("导入失败")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(importErrorMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("关闭") {
                            showImportError = false
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            Divider()
            
            // Action Buttons
            HStack {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(action: {
                    onImportManual(jsonText)
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("导入")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 550)
    }
}

// Import Mode Views

private struct FileImportView: View {
    let onSelectFile: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.badge.arrow.up.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            VStack(spacing: 12) {
                Text("从文件导入")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("选择 JSON 配置文件进行导入")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: onSelectFile) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                    Text("选择配置文件")
                }
                .font(.headline)
                .frame(minWidth: 200)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("支持格式：")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("• JSON 文件 (.json)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• UTF-8 编码")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• 有效的配置格式")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct ManualImportView: View {
    @Binding var jsonText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("配置 JSON")
                    .font(.headline)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button {
                        openFileAndLoadText()
                    } label: {
                        Label("从文件加载", systemImage: "tray.and.arrow.down")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    
                    if !jsonText.isEmpty {
                        Text("\(jsonText.count) 字符")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("清空") {
                            jsonText = ""
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
            }
            
            TextEditor(text: $jsonText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 300, maxHeight: 420)
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
            .border(Color.secondary.opacity(0.3), width: 1)
            .cornerRadius(4)
            
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("在此处粘贴或输入配置 JSON，导入前将自动进行格式校验")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private func openFileAndLoadText() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "选择配置文件"
        panel.prompt = "打开"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let data = try? Data(contentsOf: url),
                   let text = String(data: data, encoding: .utf8) {
                    jsonText = text
                }
            }
        }
    }
}

#Preview {
    SettingsTabView()
        .environmentObject(AppConfiguration())
        .environmentObject(AppCoordinator.shared)
        .frame(width: 600, height: 500)
}
