//
//  ActivityRuleEditor.swift
//  share-my-status-client
//
//  Created by Refactor on 2025-01-07.
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
        NavigationView {
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
            .navigationTitle("编辑活动分组")
            // .navigationBarTitleDisplayMode(.inline) // macOS 不支持此修饰符
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                    let group = ActivityGroup(
                        id: originalGroup.id,
                        name: name,
                        bundleIds: bundleIds.filter { !$0.isEmpty },
                        isEnabled: isEnabled
                    )
                    onSave(group)
                }
                    .disabled(name.isEmpty)
                }
            }
        }
        // 在 macOS 的 sheet 中，未指定尺寸时可能导致内容区域为 0，
        // 仅显示底部 confirmation/cancellation 按钮。设置最小尺寸并使用
        // stack 样式以确保内容正确渲染。
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

// MARK: - Legacy ActivityRuleEditor (for backward compatibility)
/// Legacy activity rule editor (deprecated, use ActivityGroupEditor instead)
struct ActivityRuleEditor: View {
    @Binding var rules: [ActivityRule]
    @State private var showingRuleEditor = false
    @State private var editingRule: ActivityRule?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("活动规则配置 (已弃用)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Button(action: {
                    editingRule = ActivityRule(pattern: "", label: "", isEnabled: true)
                    showingRuleEditor = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("添加规则")
                    }
                }
                .buttonStyle(.bordered)
            }
            
            Text("⚠️ 此功能已弃用，请使用新的活动分组功能")
                .font(.caption)
                .foregroundColor(.orange)
            
            if rules.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.badge.plus")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("暂无活动规则")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("点击\"添加规则\"创建第一个活动规则")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
                        ActivityRuleRow(
                            rule: rule,
                            onToggle: { isEnabled in
                                rules[index].isEnabled = isEnabled
                            },
                            onEdit: {
                                editingRule = rule
                                showingRuleEditor = true
                            },
                            onDelete: {
                                rules.remove(at: index)
                            }
                        )
                    }
                }
            }
            
            HStack {
                Button("恢复默认规则") {
                    rules = ActivityRule.defaultRules
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingRuleEditor) {
            if let rule = editingRule {
                ActivityRuleEditView(
                    rule: rule,
                    onSave: { updatedRule in
                        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
                            rules[index] = updatedRule
                        } else {
                            rules.append(updatedRule)
                        }
                        editingRule = nil
                        showingRuleEditor = false
                    },
                    onCancel: {
                        editingRule = nil
                        showingRuleEditor = false
                    }
                )
            }
        }
    }
}

/// Row view for displaying an activity rule
struct ActivityRuleRow: View {
    let rule: ActivityRule
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { rule.isEnabled },
                set: onToggle
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.label)
                        .font(.headline)
                        .foregroundColor(rule.isEnabled ? .primary : .secondary)
                    Text("Bundle ID: \(rule.pattern)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.orange)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

/// Edit view for activity rules
struct ActivityRuleEditView: View {
    @State private var pattern: String
    @State private var label: String
    @State private var isEnabled: Bool
    
    let onSave: (ActivityRule) -> Void
    let onCancel: () -> Void
    
    init(rule: ActivityRule, onSave: @escaping (ActivityRule) -> Void, onCancel: @escaping () -> Void) {
        self._pattern = State(initialValue: rule.pattern)
        self._label = State(initialValue: rule.label)
        self._isEnabled = State(initialValue: rule.isEnabled)
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("编辑活动规则")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Bundle ID")
                    .font(.headline)
                TextField("例如: com.apple.dt.Xcode", text: $pattern)
                    .textFieldStyle(.roundedBorder)
                Text("应用的 Bundle ID，必须完全匹配")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("状态标签")
                    .font(.headline)
                TextField("例如: 在写代码", text: $label)
                    .textFieldStyle(.roundedBorder)
                Text("匹配成功时显示的活动状态")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Toggle("启用此规则", isOn: $isEnabled)
                .font(.headline)
            
            Spacer()
            
            HStack {
                Button("取消", action: onCancel)
                    .buttonStyle(.bordered)
                
                Spacer()
                
                Button("保存") {
                    let rule = ActivityRule(
                        pattern: pattern,
                        label: label,
                        isEnabled: isEnabled
                    )
                    onSave(rule)
                }
                .buttonStyle(.borderedProminent)
                .disabled(pattern.isEmpty || label.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
    }
}

#Preview {
    ActivityGroupEditor(groups: .constant(ActivityGroup.defaultGroups))
        .frame(width: 600, height: 500)
}