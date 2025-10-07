# Project Structure - Share My Status macOS Client

## 完整文件树

```
share-my-status-client/
│
├── 📱 App Entry
│   └── share_my_status_clientApp.swift          # App入口，使用AppCoordinator
│
├── 🎨 Views/                                     # UI层 (SwiftUI)
│   ├── ContentView.swift                         # 主窗口容器
│   ├── MenuBarView.swift                         # 菜单栏视图
│   ├── MainWindow/
│   │   ├── StatusTabView.swift                   # 状态标签页
│   │   └── SettingsTabView.swift                 # 设置标签页
│   └── Components/
│       └── StatusIndicator.swift                 # 状态指示器组件
│
├── 🎯 Core/                                      # 核心协调层
│   ├── AppCoordinator.swift                      # 应用协调器 (Singleton)
│   └── StatusReporter.swift                      # 状态上报协调器
│
├── ⚙️ Services/                                  # 服务层 (Actor-based)
│   ├── Media/
│   │   ├── MediaRemoteService.swift              # 音乐检测服务
│   │   ├── MediaRemoteTypes.swift                # MediaRemote类型定义
│   │   └── README.md                             # MediaRemote集成说明
│   ├── SystemMonitorService.swift                # 系统监控服务
│   ├── ActivityDetectorService.swift             # 活动检测服务
│   ├── NetworkService.swift                      # 网络请求服务
│   └── CoverService.swift                        # 封面管理服务
│
├── 📦 Models/                                    # 数据模型层
│   ├── API/                                      # API模型 (from IDL)
│   │   ├── APIModels.swift                       # 基础响应和通用模型
│   │   ├── StateModels.swift                     # 状态上报API模型
│   │   └── CoverModels.swift                     # 封面API模型
│   ├── Domain/                                   # 领域模型
│   │   ├── MusicModels.swift                     # 音乐领域模型
│   │   ├── SystemModels.swift                    # 系统领域模型
│   │   └── ActivityModels.swift                  # 活动领域模型
│   └── Settings/
│       └── AppConfiguration.swift                # 应用配置模型
│
├── 🛠 Utilities/                                 # 工具类
│   ├── Logger.swift                              # 结构化日志
│   └── Extensions/
│       ├── Data+MD5.swift                        # MD5哈希扩展
│       └── Process+Async.swift                   # Process异步封装
│
├── 🎨 Assets.xcassets/                           # 资源文件
│   ├── AppIcon.appiconset/
│   ├── AccentColor.colorset/
│   └── Contents.json
│
├── 📄 Documentation/
│   ├── README.md                                 # 项目说明
│   └── .gitignore                                # Git忽略配置
│
└── 📋 Project Files/
    └── (Managed by Xcode)
```

## 目录职责

### Views/ - UI层
**职责**: 用户界面展示
**特点**: 
- 所有视图标记 `@MainActor`
- 使用 `@EnvironmentObject` 访问配置和reporter
- 纯SwiftUI，声明式UI

### Core/ - 核心协调层
**职责**: 协调各服务，管理应用生命周期
**特点**:
- `AppCoordinator`: Singleton，全局状态管理
- `StatusReporter`: ObservableObject，连接UI和Services

### Services/ - 服务层
**职责**: 业务逻辑和外部API交互
**特点**:
- 所有服务都是 `actor`
- 线程安全，无数据竞争
- 异步方法使用 `async/await`

### Models/ - 数据模型层
**职责**: 数据结构定义
**特点**:
- API模型严格遵循IDL
- Domain模型服务于业务逻辑
- 清晰的类型转换方法

### Utilities/ - 工具层
**职责**: 通用工具和扩展
**特点**:
- 无状态，纯函数
- 可复用
- 扩展系统类型

## 数据流

### 配置流 (向下)
```
User Input (UI)
    ↓
AppConfiguration (@Published)
    ↓
AppCoordinator (observes)
    ↓
StatusReporter.updateConfiguration()
    ↓
Service Actors (async update)
```

### 状态流 (向上)
```
System APIs
    ↓
Service Actors (collect)
    ↓
StatusReporter (coordinate)
    ↓
@Published Properties
    ↓
UI Updates (SwiftUI)
```

### 上报流
```
Timer → StatusReporter.performReport()
    ↓
Parallel collection:
├── MediaRemoteService.getCurrentMusic()
├── SystemMonitorService.getCurrentSnapshot()
└── ActivityDetectorService.getCurrentActivity()
    ↓
CoverService.checkAndUploadCover() [if needed]
    ↓
Build ReportEvent
    ↓
NetworkService.reportStatus()
    ↓
Update lastError / statistics
```

## 线程模型

### Main Thread (@MainActor)
- UI更新
- Configuration变更
- StatusReporter状态
- AppCoordinator

### Background Threads (Actors)
- MediaRemoteService (音乐检测)
- SystemMonitorService (系统监控)
- ActivityDetectorService (活动检测)
- NetworkService (网络请求)
- CoverService (封面上传)

### 通信机制

**MainActor → Actor**:
```swift
// 异步调用
let snapshot = await service.getCurrentSnapshot()
```

**Actor → MainActor**:
```swift
// 通过closure回调
try await service.startStreaming { data in
    Task { @MainActor in
        self.publishedProperty = data
    }
}
```

## 依赖关系

```
AppCoordinator (singleton)
    ├── AppConfiguration
    └── StatusReporter
            ├── MediaRemoteService
            ├── SystemMonitorService
            ├── ActivityDetectorService
            ├── NetworkService
            └── CoverService
```

### 服务间依赖

- **NetworkService** ← StatusReporter (上报时调用)
- **CoverService** ← StatusReporter (上报前上传封面)
- **所有服务** ← StatusReporter (配置更新)

### 无循环依赖
所有依赖都是单向的，避免了循环引用。

## 文件计数

- **Swift源文件**: 27个
- **文档文件**: 6个
- **资源文件**: 3个 (Assets)
- **配置文件**: 2个 (.gitignore, xcodeproj)

**总计**: ~38个文件

## 代码行数估算

- Models: ~600行
- Services: ~1000行
- Core: ~400行
- Views: ~500行
- Utilities: ~200行
- Documentation: ~1500行

**总计**: ~4200行代码和文档

## 对比旧架构

### 文件数量
- 旧: 8个主要Swift文件
- 新: 27个Swift文件
- **增加**: 更好的模块化

### 代码行数
- 旧: ~2000行
- 新: ~2700行 (代码)
- **增加**: 更多类型安全和错误处理

### 架构复杂度
- 旧: DispatchQueue + Callbacks
- 新: Actors + Async/Await
- **改善**: 更清晰，更安全

## 维护指南

### 添加新功能

1. **新的数据源**:
   - 创建新的Actor service
   - 在StatusReporter中集成
   - 更新UI显示

2. **新的API**:
   - 更新Models/API/
   - 在NetworkService或新Service中实现
   - 更新StatusReporter调用

3. **新的UI**:
   - 在Views/创建新组件
   - 使用 `@EnvironmentObject` 访问状态
   - 遵循现有模式

### 修改现有功能

1. 找到对应的Service actor
2. 修改actor方法
3. 如需要，更新StatusReporter
4. 测试线程安全

### 调试技巧

1. **使用Logger**:
   ```swift
   AppLogger.media.debug("Message")
   ```

2. **Console.app过滤**:
   - Subsystem: `com.wujunyi792.share-my-status-client`
   - Category: Media, System, Activity, etc.

3. **Instruments**:
   - Time Profiler (性能)
   - Leaks (内存泄漏)
   - Network (网络请求)

---

**项目结构清晰，易于维护！** 🚀

