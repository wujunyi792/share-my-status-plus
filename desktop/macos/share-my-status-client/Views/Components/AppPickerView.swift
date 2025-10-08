//
//  AppPickerView.swift
//  share-my-status-client
//
//  Created by Refactor on 2025-01-07.
//

import SwiftUI
import AppKit
import Combine

struct AppInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let icon: NSImage?
}

class ApplicationScanner: ObservableObject {
    @Published var runningApplications: [AppInfo] = []

    func scan() {
        DispatchQueue.global(qos: .userInitiated).async {
            var applications: [AppInfo] = []
            let fileManager = FileManager.default
            
            let applicationDirectoryURLs = fileManager.urls(for: .applicationDirectory, in: .allDomainsMask)

            for url in applicationDirectoryURLs {
                guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [], options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: nil) else { continue }
                
                for case let fileURL as URL in enumerator {
                    if fileURL.pathExtension == "app" {
                        if let bundle = Bundle(url: fileURL), let bundleId = bundle.bundleIdentifier {
                            if !applications.contains(where: { $0.bundleIdentifier == bundleId }) {
                                let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? fileURL.deletingPathExtension().lastPathComponent
                                let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
                                let appInfo = AppInfo(name: name, bundleIdentifier: bundleId, icon: icon)
                                applications.append(appInfo)
                            }
                        }
                        enumerator.skipDescendants()
                    }
                }
            }
            
            let sortedApps = applications.sorted { $0.name.lowercased() < $1.name.lowercased() }
            
            DispatchQueue.main.async {
                self.runningApplications = sortedApps
            }
        }
    }
}

struct AppPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var scanner = ApplicationScanner()
    @Binding var selectedApps: [String]
    @State private var searchText = ""
    let title: String
    let mode: AppPickerMode
    
    enum AppPickerMode {
        case whitelist  // 白名单模式：选中的应用会被添加
        case blacklist  // 黑名单模式：选中的应用会被排除
        
        var addButtonText: String {
            switch self {
            case .whitelist: return "添加"
            case .blacklist: return "添加"
            }
        }
        
        var removeButtonText: String {
            switch self {
            case .whitelist: return "移除"
            case .blacklist: return "移除"
            }
        }
        
        var clearAllButtonText: String {
            switch self {
            case .whitelist: return "全部移除"
            case .blacklist: return "全部移除"
            }
        }
    }

    var filteredApps: [AppInfo] {
        let apps: [AppInfo]
        if searchText.isEmpty {
            apps = scanner.runningApplications
        } else {
            apps = scanner.runningApplications.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText) }
        }
        
        // 按选中状态排序：已选择的应用排在前面
        return apps.sorted { app1, app2 in
            let isSelected1 = selectedApps.contains(app1.bundleIdentifier)
            let isSelected2 = selectedApps.contains(app2.bundleIdentifier)
            
            if isSelected1 && !isSelected2 {
                return true  // app1 已选择，app2 未选择，app1 排在前面
            } else if !isSelected1 && isSelected2 {
                return false // app1 未选择，app2 已选择，app2 排在前面
            } else {
                // 两者选中状态相同，按名称排序
                return app1.name.lowercased() < app2.name.lowercased()
            }
        }
    }

    var body: some View {
        VStack {
            Text(title)
                .font(.title)
                .padding()

            TextField("搜索应用...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .controlSize(.large)

            List(filteredApps) { app in
                AppRowView(app: app, selectedApps: $selectedApps, mode: mode)
            }
            .onAppear {
                scanner.scan()
            }

            HStack {
                Button(mode.clearAllButtonText) {
                    selectedApps.removeAll()
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.large)

                Spacer()

                Button("完成") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
    }
}

struct AppRowView: View {
    let app: AppInfo
    @Binding var selectedApps: [String]
    let mode: AppPickerView.AppPickerMode

    var body: some View {
        HStack {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .cornerRadius(4)
            } else {
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 32, height: 32)
                    .cornerRadius(4)
            }
            VStack(alignment: .leading) {
                Text(app.name).font(.headline)
                Text(app.bundleIdentifier).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if selectedApps.contains(app.bundleIdentifier) {
                Button(mode.removeButtonText) {
                    selectedApps.removeAll { $0 == app.bundleIdentifier }
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.large)
                .frame(minWidth: 80)
            } else {
                Button(mode.addButtonText) {
                    selectedApps.append(app.bundleIdentifier)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(minWidth: 80)
            }
        }
        .padding(.vertical, 4)
    }
}