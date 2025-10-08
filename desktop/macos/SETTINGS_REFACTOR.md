# 默认设置统一管理重构

## 📋 重构概述

本次重构将客户端代码中散落在各处的默认设置值统一集中到一个文件中管理，解决了"恢复默认"功能初始值不一致的问题。

## 🎯 重构目标

1. ✅ 统一管理所有默认设置值
2. ✅ 消除代码中的硬编码默认值
3. ✅ 确保"恢复默认"功能使用统一的数据源
4. ✅ 提高代码可维护性

## 📝 主要变更

### 1. 新增文件

#### `Models/Settings/DefaultSettings.swift`
新增的默认设置统一管理中心，包含：

- **网络配置**
  - `endpointURL`: API 服务器地址
  - `secretKey`: API 密钥

- **功能开关**
  - `isReportingEnabled`: 总开关
  - `musicReportingEnabled`: 音乐上报
  - `systemReportingEnabled`: 系统监控
  - `activityReportingEnabled`: 活动检测

- **应用列表**
  - `musicAppWhitelist`: 音乐应用白名单
  - `activityAppBlacklist`: 活动黑名单

- **轮询间隔**
  - `reportInterval`: 上报间隔（已废弃）
  - `systemPollingInterval`: 系统监控轮询间隔
  - `activityPollingInterval`: 活动检测轮询间隔

- **轮询间隔范围**
  - `systemPollingIntervalRange`: 系统监控间隔范围 (5...60 秒)
  - `activityPollingIntervalRange`: 活动检测间隔范围 (1...30 秒)
  - 对应的步长配置

- **活动配置**
  - `idleTimeThreshold`: 空闲时间阈值（300 秒）
  - `activityGroups`: 默认活动分组
  - `activityRules`: 默认活动规则（已废弃）

#### `Models/Settings/README.md`
新增的设置模块文档，说明：
- 文件结构和用途
- 使用方式和示例
- 架构设计
- 修改指南

### 2. 更新的文件

#### `AppConfiguration.swift`
- ✅ 所有 `init()` 中的默认值改为使用 `DefaultSettings`
- ✅ `resetToDefaults()` 方法直接使用 `DefaultSettings` 而不是创建新实例
- ✅ 移除所有硬编码的默认值

**修改前：**
```swift
self.endpointURL = UserDefaults.standard.string(forKey: "endpointURL") ?? "https://api.example.com/v1/state/report"
```

**修改后：**
```swift
self.endpointURL = UserDefaults.standard.string(forKey: "endpointURL") ?? DefaultSettings.endpointURL
```

#### `ActivityModels.swift`
- ✅ `ActivityGroup.defaultGroups` 改为计算属性，返回 `DefaultSettings.activityGroups`
- ✅ `ActivityRule.defaultRules` 改为计算属性，返回 `DefaultSettings.activityRules`
- ✅ `isIdle` 计算属性使用 `DefaultSettings.idleTimeThreshold`

**修改前：**
```swift
static let defaultGroups = [
    ActivityGroup(name: "在工作", bundleIds: [...], isEnabled: true),
    // ...
]
```

**修改后：**
```swift
static var defaultGroups: [ActivityGroup] {
    return DefaultSettings.activityGroups
}
```

#### `SettingsTabView.swift`
- ✅ Slider 范围配置使用 `DefaultSettings` 中的范围和步长
- ✅ TextField placeholder 使用 `DefaultSettings.endpointURL`
- ✅ AppListEditor 的 defaultApps 使用 `DefaultSettings.musicAppWhitelist`

**修改前：**
```swift
Slider(value: ..., in: 5...60, step: 5)
```

**修改后：**
```swift
Slider(
    value: ...,
    in: DefaultSettings.systemPollingIntervalRange,
    step: DefaultSettings.systemPollingIntervalStep
)
```

## 📊 重构效果

### 重构前的问题
1. ❌ 默认值散落在 3+ 个文件中
2. ❌ 相同的值在不同地方重复定义
3. ❌ "恢复默认"功能通过创建新实例获取默认值，效率低
4. ❌ 修改默认值需要在多个地方更新

### 重构后的优势
1. ✅ 所有默认值在一个文件中管理
2. ✅ 单一数据源，避免不一致
3. ✅ "恢复默认"直接使用静态常量，高效可靠
4. ✅ 修改默认值只需在一处更新
5. ✅ 代码更清晰，可维护性更强

## 🔍 验证清单

- [x] 所有默认值已迁移到 `DefaultSettings.swift`
- [x] `AppConfiguration.init()` 使用 `DefaultSettings`
- [x] `AppConfiguration.resetToDefaults()` 使用 `DefaultSettings`
- [x] `ActivityModels` 的静态默认值引用 `DefaultSettings`
- [x] UI 组件的硬编码默认值已移除
- [x] Slider 范围配置使用 `DefaultSettings`
- [x] 无编译错误
- [x] 代码文档已更新

## 🚀 后续优化建议

1. 考虑将 `DefaultSettings` 改为 `struct` 并使用 `static let` 确保不可变性
2. 可以为不同环境（开发/生产）提供不同的默认配置
3. 考虑添加单元测试验证默认值的正确性

## 📚 相关文件

- `Models/Settings/DefaultSettings.swift` - 默认设置管理中心
- `Models/Settings/AppConfiguration.swift` - 应用配置管理
- `Models/Settings/README.md` - 设置模块文档
- `Models/Domain/ActivityModels.swift` - 活动模型
- `Views/MainWindow/SettingsTabView.swift` - 设置视图
- `Views/Components/ActivityRuleEditor.swift` - 活动规则编辑器

---

**重构完成时间：** 2025-01-07  
**影响范围：** 设置管理相关的所有文件  
**破坏性变更：** 无（向后兼容）

