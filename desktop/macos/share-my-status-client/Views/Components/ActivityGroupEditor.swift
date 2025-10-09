//
//  ActivityGroupEditor.swift
//  share-my-status-client
//


import SwiftUI

/// Activity group editor for managing activity groups and their bundle IDs
struct ActivityGroupEditor: View {
    @Binding var groups: [ActivityGroup]
    @State private var showingGroupEditor = false
    @State private var editingGroup: ActivityGroup?
    @State private var showingAppPicker = false
    @State private var selectedGroupIndex: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("活动分组配置")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    editingGroup = ActivityGroup(name: "", bundleIds: [], isEnabled: true)
                    showingGroupEditor = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("添加分组")
                    }
                }
                .buttonStyle(.bordered)
            }
            
            Text("配置不同的活动分组，每个分组可以包含多个应用的 Bundle ID")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if groups.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "folder.badge.plus")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("暂无活动分组")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("点击\"添加分组\"创建第一个活动分组")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                        ActivityGroupRow(
                            group: group,
                            onToggle: { isEnabled in
                                groups[index].isEnabled = isEnabled
                            },
                            onEdit: {
                                editingGroup = group
                                showingGroupEditor = true
                            },
                            onDelete: {
                                groups.remove(at: index)
                            },
                            onAddBundleId: {
                                selectedGroupIndex = index
                                showingAppPicker = true
                            }
                        )
                    }
                }
            }
            
            HStack {
                Button("恢复默认分组") {
                    groups = ActivityGroup.defaultGroups
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingGroupEditor) {
            if let group = editingGroup {
                ActivityGroupEditView(
                    group: group,
                    onSave: { updatedGroup in
                        if let index = groups.firstIndex(where: { $0.id == group.id }) {
                            groups[index] = updatedGroup
                        } else {
                            groups.append(updatedGroup)
                        }
                        editingGroup = nil
                        showingGroupEditor = false
                    },
                    onCancel: {
                        editingGroup = nil
                        showingGroupEditor = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingAppPicker) {
            if let index = selectedGroupIndex {
                AppPickerView(
                    selectedApps: Binding(
                        get: { groups[index].bundleIds },
                        set: { groups[index].bundleIds = $0 }
                    ),
                    title: "为\"\(groups[index].name)\"选择应用",
                    mode: .whitelist
                )
            }
        }
    }
}

/// Row view for displaying an activity group
struct ActivityGroupRow: View {
    let group: ActivityGroup
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onAddBundleId: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(isOn: Binding(
                    get: { group.isEnabled },
                    set: onToggle
                )) {
                    Text(group.name)
                        .font(.headline)
                        .foregroundColor(group.isEnabled ? .primary : .secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: onAddBundleId) {
                        Image(systemName: "plus.app")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.blue)
                    .help("添加应用")
                    
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.orange)
                    .help("编辑分组")
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                    .help("删除分组")
                }
            }
            
            if !group.bundleIds.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("包含的应用 (\(group.bundleIds.count)):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 200))
                    ], spacing: 4) {
                        ForEach(group.bundleIds, id: \.self) { bundleId in
                            Text(bundleId)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding(.leading, 20)
            } else {
                Text("暂无应用")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

/// Edit view for activity groups
struct ActivityGroupEditView: View {
    @State private var name: String
    @State private var bundleIds: [String]
    @State private var isEnabled: Bool
    @State private var newBundleId: String = ""
    @State private var showingAppPicker = false
    
    private let originalGroup: ActivityGroup
    let onSave: (ActivityGroup) -> Void
    let onCancel: () -> Void
    
    init(group: ActivityGroup, onSave: @escaping (ActivityGroup) -> Void, onCancel: @escaping () -> Void) {
        self.originalGroup = group
        self._name = State(initialValue: group.name)
        self._bundleIds = State(initialValue: group.bundleIds)
        self._isEnabled = State(initialValue: group.isEnabled)
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("编辑活动分组")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 内容区域
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("分组名称")
                        .font(.headline)
                    TextField("例如: 在工作", text: $name)
                        .textFieldStyle(.roundedBorder)
                    Text("活动分组的显示名称")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Bundle ID 列表")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("从应用选择") {
                            showingAppPicker = true
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if bundleIds.isEmpty {
                        Text("暂无应用")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 20)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(Array(bundleIds.enumerated()), id: \.offset) { index, bundleId in
                                    HStack {
                                        TextField("Bundle ID", text: Binding(
                                            get: { bundleId },
                                            set: { bundleIds[index] = $0 }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                        
                                        Button(action: {
                                            bundleIds.remove(at: index)
                                        }) {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.borderless)
                                        .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                    
                    HStack {
                        TextField("手动添加 Bundle ID", text: $newBundleId)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                if !newBundleId.isEmpty && !bundleIds.contains(newBundleId) {
                                    bundleIds.append(newBundleId)
                                    newBundleId = ""
                                }
                            }
                        
                        Button("添加") {
                            if !newBundleId.isEmpty && !bundleIds.contains(newBundleId) {
                                bundleIds.append(newBundleId)
                                newBundleId = ""
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(newBundleId.isEmpty || bundleIds.contains(newBundleId))
                    }
                }
                
                Toggle("启用此分组", isOn: $isEnabled)
                    .font(.headline)
                
                Spacer()
            }
            .padding()
            
            Divider()
            
            // 底部按钮
            HStack {
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("保存") {
                    let group = ActivityGroup(
                        id: originalGroup.id,
                        name: name,
                        bundleIds: bundleIds.filter { !$0.isEmpty },
                        isEnabled: isEnabled
                    )
                    onSave(group)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 520, minHeight: 420)
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView(
                selectedApps: $bundleIds,
                title: "选择要添加到\"\(name)\"的应用",
                mode: .whitelist
            )
        }
    }
}

