//
//  CustomLinkView.swift
//  share-my-status-client
//
//  Custom link builder for Feishu signature integration
//

import SwiftUI

/// View for customizing Feishu signature links with music and system info
struct CustomLinkView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var statusReporter: StatusReporter
    @EnvironmentObject var configuration: AppConfiguration
    
    @State private var baseUrl: String = ""
    @State private var redirectUrl: String = ""
    @State private var displayFormat: String = "正在听{artist}-{title}"
    @State private var customizedUrl: String = ""
    @State private var previewText: String = ""
    @State private var showCopySuccess: Bool = false
    @State private var isPlaceholderExpanded: Bool = false
    
    private var isValidBaseUrl: Bool {
        LinkUtility.isValidBaseUrl(baseUrl)
    }
    
    private var isValidRedirectUrl: Bool {
        LinkUtility.isValidRedirectUrl(redirectUrl)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar with close button
            HStack {
                Text("飞书链接定制工具")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .help("关闭")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Description
                    Text("创建包含实时状态信息的定制链接。设置完成后，粘贴进飞书个性签名即可展示你设置的文字内容，点击可跳转到指定网址。")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                
                Divider()
                
                // Base URL Input
                GroupBox("基础链接") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("基础链接可以通过飞书机器人获取或使用分享链接")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("输入基础链接 (必须以 https:// 或 http:// 开头)", text: $baseUrl)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: baseUrl) { newValue in
                                parseUrlAndUpdateFields(newValue)
                                updateCustomizedUrl()
                            }
                        
                        if !baseUrl.isEmpty && !isValidBaseUrl {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .imageScale(.small)
                                Text("基础链接必须以 https:// 或 http:// 开头")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                // Redirect URL Input
                GroupBox("点击后跳转链接 (可选)") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("设置点击链接后跳转的目标地址")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("输入跳转链接 (必须以 http:// 或 https:// 开头)", text: $redirectUrl)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: redirectUrl) { _ in
                                updateCustomizedUrl()
                            }
                        
                        if !redirectUrl.isEmpty && !isValidRedirectUrl {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .imageScale(.small)
                                Text("跳转链接必须以 http:// 或 https:// 开头")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                // Display Format Input
                GroupBox("显示文本格式") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("使用占位符自定义显示的文字内容")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("输入显示文本格式", text: $displayFormat)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: displayFormat) { _ in
                                updateCustomizedUrl()
                                updatePreview()
                            }
                        
                        // Real-time Preview (moved here for better UX)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "eye.fill")
                                    .foregroundColor(.blue)
                                    .imageScale(.small)
                                Text("实时预览:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if hasAnyData {
                                Text(previewText)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            } else {
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.secondary)
                                        .imageScale(.small)
                                    Text("启动状态上报后将显示预览效果")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                        
                        Divider()
                        
                        // Quick insert buttons - Music
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Text("🎵 音乐:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Button("艺术家") { insertPlaceholder("{artist}") }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                
                                Button("标题") { insertPlaceholder("{title}") }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                
                                Button("专辑") { insertPlaceholder("{album}") }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                            
                            // Quick insert buttons - System
                            HStack(spacing: 6) {
                                Text("💻 系统:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Button("电量%") { insertPlaceholder("{batteryPctRounded}") }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                
                                Button("CPU%") { insertPlaceholder("{cpuPctRounded}") }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                
                                Button("内存%") { insertPlaceholder("{memoryPctRounded}") }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                
                                Button("充电状态") { insertPlaceholder("{charging?'⚡':'🔋'}") }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                            
                            // Quick insert buttons - Activity & Time
                            HStack(spacing: 6) {
                                Text("📌 其他:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Button("活动") { insertPlaceholder("{activityLabel}") }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                
                                Button("日期") { insertPlaceholder("{dateYMD}") }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                
                                Button("时间") { insertPlaceholder("{nowLocal}") }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        }
                        
                        // Help text (collapsible with better UI)
                        VStack(alignment: .leading, spacing: 8) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isPlaceholderExpanded.toggle()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: isPlaceholderExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                                        .foregroundColor(.blue)
                                        .imageScale(.medium)
                                    
                                    Text("支持的占位符")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text(isPlaceholderExpanded ? "收起" : "展开查看")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .help("点击查看所有可用的占位符变量")
                            
                            if isPlaceholderExpanded {
                                VStack(alignment: .leading, spacing: 6) {
                                    PlaceholderRow(category: "音乐", placeholders: "{artist}, {title}, {album}")
                                    PlaceholderRow(category: "系统", placeholders: "{batteryPctRounded}, {cpuPctRounded}, {memoryPctRounded}")
                                    PlaceholderRow(category: "活动", placeholders: "{activityLabel}")
                                    PlaceholderRow(category: "时间", placeholders: "{nowLocal}, {dateYMD}, {nowISO}")
                                    PlaceholderRow(category: "条件", placeholders: "{charging?'充电中':'未充电'}")
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(6)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                }
                
                // Generated Link
                GroupBox("定制链接") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("系统根据你的设置自动生成的完整链接")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("定制链接将显示在这里", text: $customizedUrl)
                            .textFieldStyle(.roundedBorder)
                            .disabled(true)
                            .textSelection(.enabled)
                        
                        // Action buttons
                        HStack(spacing: 10) {
                            Button(action: copyLink) {
                                Label("复制链接", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(customizedUrl.isEmpty)
                            
                            Button(action: copyAndOpen) {
                                Label("复制并打开", systemImage: "arrow.up.forward.app")
                            }
                            .buttonStyle(.bordered)
                            .disabled(customizedUrl.isEmpty)
                            
                            Spacer()
                            
                            Button(action: clearFields) {
                                Label("清空", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            .disabled(baseUrl.isEmpty && redirectUrl.isEmpty && displayFormat == "正在听{artist}-{title}")
                        }
                        
                        if showCopySuccess {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .imageScale(.small)
                                Text("已复制到剪贴板")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                
                    Spacer()
                }
                .padding()
            }
            .onAppear {
                updatePreview()
            }
            .onReceive(statusReporter.$currentMusic) { _ in
                updatePreview()
            }
            .onReceive(statusReporter.$currentSystem) { _ in
                updatePreview()
            }
            .onReceive(statusReporter.$currentActivity) { _ in
                updatePreview()
            }
        }
    }
    
    // Helper Methods
    
    private var hasAnyData: Bool {
        statusReporter.currentMusic != nil ||
        statusReporter.currentSystem != nil ||
        statusReporter.currentActivity != nil
    }
    
    private func insertPlaceholder(_ placeholder: String) {
        displayFormat += placeholder
        updateCustomizedUrl()
        updatePreview()
    }
    
    private func parseUrlAndUpdateFields(_ url: String) {
        guard !url.isEmpty else { return }
        
        if let parsed = LinkUtility.parseCustomizedUrl(url) {
            // Normalize base URL to /s/{sharingKey} format if needed
            if parsed.baseUrl != url {
                baseUrl = parsed.baseUrl
            }
            
            if let redirect = parsed.redirectUrl {
                redirectUrl = redirect
            }
            if let format = parsed.displayFormat {
                displayFormat = format
            }
        }
    }
    
    private func updateCustomizedUrl() {
        guard isValidBaseUrl else {
            customizedUrl = ""
            return
        }
        
        if let url = LinkUtility.createCustomizedUrl(
            baseUrl: baseUrl,
            redirectUrl: redirectUrl.isEmpty ? nil : redirectUrl,
            displayFormat: displayFormat
        ) {
            customizedUrl = url
        } else {
            customizedUrl = ""
        }
    }
    
    private func updatePreview() {
        var variables = LinkUtility.TemplateVariables()
        
        // Fill in music data
        if let music = statusReporter.currentMusic {
            variables.artist = music.artist
            variables.title = music.title
            variables.album = music.album
        }
        
        // Fill in system data
        if let system = statusReporter.currentSystem {
            variables.batteryPct = system.batteryLevel
            variables.charging = system.isCharging ?? false
            variables.cpuPct = system.cpuUsage
            variables.memoryPct = system.memoryUsage
        }
        
        // Fill in activity data
        if let activity = statusReporter.currentActivity {
            variables.activityLabel = activity.activityTag
        }
        
        // Current time
        variables.now = Date()
        
        previewText = LinkUtility.formatDisplayText(format: displayFormat, variables: variables)
    }
    
    private func copyLink() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(customizedUrl, forType: .string)
        
        showCopySuccess = true
        
        // Hide success message after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopySuccess = false
        }
    }
    
    private func copyAndOpen() {
        copyLink()
        
        if let url = URL(string: customizedUrl) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func clearFields() {
        baseUrl = ""
        redirectUrl = ""
        displayFormat = "正在听{artist}-{title}"
        customizedUrl = ""
        updatePreview()
    }
}

// Supporting Views

/// Row view for displaying placeholder category and values
private struct PlaceholderRow: View {
    let category: String
    let placeholders: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(category + ":")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)
            
            Text(placeholders)
                .font(.caption)
                .foregroundColor(.primary)
                .textSelection(.enabled)  // Enable text selection
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// Preview

#Preview {
    CustomLinkView()
        .environmentObject(StatusReporter())
        .environmentObject(AppConfiguration())
        .frame(width: 600, height: 800)
}

