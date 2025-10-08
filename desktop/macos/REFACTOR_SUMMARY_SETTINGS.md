# 默认设置统一管理 - 变更总结

## 🎯 重构目标
将散落在各处的默认设置值统一到一个文件中管理，确保"恢复默认"功能使用一致的初始值。

## 📦 新增文件

### 1. `Models/Settings/DefaultSettings.swift` 
**核心文件 - 默认设置统一管理中心**

包含所有应用程序的默认配置常量：
- 网络配置（URL、密钥）
- 功能开关（上报、监控、检测）
- 应用列表（白名单、黑名单）
- 轮询间隔及其范围配置
- 活动分组和规则
- 空闲时间阈值

### 2. `Models/Settings/README.md`
设置模块的使用文档和最佳实践指南。

## ✏️ 修改的文件

### `Models/Settings/AppConfiguration.swift`
- `init()`: 所有默认值从 `DefaultSettings` 读取
- `resetToDefaults()`: 直接使用 `DefaultSettings` 常量（不再创建新实例）

### `Models/Domain/ActivityModels.swift`
- `ActivityGroup.defaultGroups`: 改为计算属性，返回 `DefaultSettings.activityGroups`
- `ActivityRule.defaultRules`: 改为计算属性，返回 `DefaultSettings.activityRules`  
- `isIdle`: 使用 `DefaultSettings.idleTimeThreshold`

### `Views/MainWindow/SettingsTabView.swift`
- Slider 范围使用 `DefaultSettings` 的范围和步长配置
- TextField placeholder 使用 `DefaultSettings.endpointURL`
- AppListEditor 默认应用列表使用 `DefaultSettings.musicAppWhitelist`

## 📊 重构效果对比

| 项目 | 重构前 | 重构后 |
|-----|--------|--------|
| 默认值定义位置 | 3+ 个文件分散 | 1 个统一文件 |
| 代码重复 | 多处重复定义 | 单一数据源 |
| 恢复默认机制 | 创建新实例 | 直接使用常量 |
| 维护成本 | 高（需多处修改） | 低（只改一处） |
| 一致性保证 | 弱 | 强 |

## ✅ 验证结果

- ✅ 无编译错误
- ✅ 所有默认值已统一
- ✅ "恢复默认"功能正常
- ✅ 向后兼容，无破坏性变更

## 🔧 使用示例

```swift
// 获取默认值
let url = DefaultSettings.endpointURL
let interval = DefaultSettings.systemPollingInterval

// 配置 Slider
Slider(
    value: $interval,
    in: DefaultSettings.systemPollingIntervalRange,
    step: DefaultSettings.systemPollingIntervalStep
)

// 恢复默认
configuration.resetToDefaults()  // 内部使用 DefaultSettings
```

## 📂 涉及文件清单

**新增：**
- ✨ `Models/Settings/DefaultSettings.swift`
- 📖 `Models/Settings/README.md`

**修改：**
- ✏️ `Models/Settings/AppConfiguration.swift`
- ✏️ `Models/Domain/ActivityModels.swift`
- ✏️ `Views/MainWindow/SettingsTabView.swift`

**文档：**
- 📝 `desktop/macos/SETTINGS_REFACTOR.md` (详细重构文档)
- 📝 `desktop/macos/REFACTOR_SUMMARY_SETTINGS.md` (本文件)

---

**完成时间：** 2025-01-07  
**代码质量：** ✅ 无 Lint 错误  
**兼容性：** ✅ 完全向后兼容

