# 客户端架构更新 - 监听器机制重构

## 更新日期
2025-01-07

## 更新概述

本次更新重构了客户端的监听器架构，将信息监听机制分为**轮询（Polling）**和**回调通知（Event-Driven）**两种机制，优化了上报效率，并实现了监听器的精确启停管理。

## 主要变更

### 1. 监听器协议系统（MonitoringProtocols.swift）

创建了统一的监听器协议体系：

- **`MonitoringType`**: 区分监听器类型
  - `polling`: 轮询类型（定期采集数据）
  - `eventDriven`: 事件驱动类型（变化时触发）

- **`MonitoringService`**: 所有监听服务的基础协议
  - 定义启停接口 `start()` / `stop()`
  - 状态查询 `isActive()`

- **`PollingMonitoringService`**: 轮询类型监听器协议
  - 支持动态调整轮询间隔 `updatePollingInterval(_:)`
  - 适用于系统状态、活动检测

- **`EventDrivenMonitoringService`**: 事件驱动监听器协议
  - 支持回调注册 `registerCallback(_:)`
  - 适用于音乐播放监听

### 2. 配置模型更新（AppConfiguration.swift）

新增独立的轮询间隔配置：

- **`systemPollingInterval`**: 系统监控轮询间隔（默认：10秒）
- **`activityPollingInterval`**: 活动检测轮询间隔（默认：5秒）

原有的 `reportInterval` 保留作为向后兼容，但不再使用。

### 3. 服务实现更新

#### SystemMonitorService（系统监控）
- ✅ 实现 `PollingMonitoringService` 协议
- ✅ 支持动态调整轮询间隔
- ✅ 按配置的间隔定期采集系统指标（CPU、内存、电池）

#### ActivityDetectorService（活动检测）
- ✅ 实现 `PollingMonitoringService` 协议
- ✅ 支持动态调整轮询间隔
- ✅ 按配置的间隔定期检测活跃应用

#### MediaRemoteService（音乐监听）
- ✅ 实现 `EventDrivenMonitoringService` 协议
- ✅ 支持回调注册机制
- ✅ 音乐变化时立即触发回调（不再定期轮询）

### 4. StatusReporter 重构

#### 上报机制分离

原有的统一定时器被替换为：

1. **事件驱动上报（音乐）**
   - 音乐变化时立即上报
   - 无需等待定时器
   - 实时性更高

2. **轮询上报（系统、活动）**
   - 每个服务独立的定时器
   - 按各自的轮询间隔上报
   - `systemReportTimer`: 系统状态上报定时器
   - `activityReportTimer`: 活动状态上报定时器

#### 报告方法重构

- **`reportMusicChange(_:)`**: 音乐变化时立即上报（事件驱动）
- **`reportSystemStatus()`**: 定期上报系统状态（轮询）
- **`reportActivityStatus()`**: 定期上报活动状态（轮询）
- **`sendReport(event:source:)`**: 统一的报告发送方法

#### 监听器启停管理

- ✅ 只启动已开启功能的监听器
- ✅ 未开启的功能不会启动监听器，完全不运行
- ✅ 配置变更时动态重启监听器应用新间隔
- ✅ 停止时正确清理所有定时器和监听器

## 架构优势

### 1. 性能优化
- **减少无效轮询**: 音乐变化采用事件驱动，无需定期查询
- **降低CPU占用**: 只有开启的功能才运行监听器
- **减少网络请求**: 按实际需要上报，避免无数据的空请求

### 2. 实时性提升
- **音乐变化立即上报**: 从定时轮询（最多5秒延迟）变为即时响应
- **独立上报间隔**: 系统和活动可以设置不同的轮询频率

### 3. 可配置性增强
- **灵活的间隔配置**: 每个轮询服务可独立配置轮询间隔
- **动态更新**: 配置变更时无需重启应用，自动应用新配置

### 4. 代码可维护性
- **清晰的协议分层**: 统一的接口，易于扩展新的监听器类型
- **职责分离**: 每个服务独立管理自己的监听逻辑
- **类型安全**: 使用 Actor 确保线程安全

## 使用示例

### 配置轮询间隔

```swift
// 在配置界面或代码中设置
config.systemPollingInterval = 15.0  // 系统监控每15秒轮询一次
config.activityPollingInterval = 3.0 // 活动检测每3秒轮询一次
```

### 监听器状态

启用后的状态显示：
```
正在上报: 音乐(事件), 系统(轮询), 活动(轮询)
```

## 向后兼容

- 保留了 `reportInterval` 配置项（不再使用）
- 自动使用新的独立间隔配置
- 现有配置在升级后使用默认值

## 日志输出示例

### 启动日志
```
[Reporter] Starting music reporting service (event-driven)...
[Media] Music streaming started (event-driven)
[Reporter] Starting system monitoring (polling, interval: 10.0s)...
[System] Starting system monitoring with interval 10.0s...
[Reporter] Starting activity detection (polling, interval: 5.0s)...
[Activity] Starting activity detection with interval 5.0s...
```

### 上报日志
```
[Reporter] Music change event: 周杰伦 - 晴天
[Reporter] [music] Report sent successfully: accepted=1
[Reporter] System status collected
[Reporter] [system] Report sent successfully: accepted=1
[Reporter] Activity status collected: 开发
[Reporter] [activity] Report sent successfully: accepted=1
```

## 测试建议

1. **功能测试**
   - 测试音乐变化时的即时上报
   - 验证系统和活动按间隔轮询
   - 测试开关功能时监听器的启停

2. **性能测试**
   - 监控CPU和内存使用
   - 验证未开启的功能确实不运行
   - 测试不同轮询间隔的影响

3. **配置测试**
   - 修改轮询间隔后验证生效
   - 测试极端值（如1秒、60秒）
   - 验证配置持久化

## 后续优化方向

1. **批量上报优化**: 考虑在短时间内多个事件时合并上报
2. **智能间隔调整**: 根据网络状况自动调整轮询间隔
3. **电池优化**: 低电量时自动降低轮询频率
4. **UI配置界面**: 在设置中添加轮询间隔的可视化配置

## 影响的文件

- 新增: `Core/MonitoringProtocols.swift`
- 修改: `Models/Settings/AppConfiguration.swift`
- 修改: `Services/SystemMonitorService.swift`
- 修改: `Services/ActivityDetectorService.swift`
- 修改: `Services/Media/MediaRemoteService.swift`
- 修改: `Core/StatusReporter.swift`

## 版本信息

- 架构版本: 2.0
- 更新时间: 2025-01-07
- 兼容性: macOS 12.0+
