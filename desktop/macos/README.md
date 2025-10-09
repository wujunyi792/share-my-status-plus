# Share My Status macOS Client - 完整文档

> 本文档整合了 Share My Status macOS 客户端的完整技术文档，包括项目概述、快速开始、架构设计、项目结构、部署指南和部署检查清单。

---

## 目录

1. [项目概述](#项目概述)
2. [快速开始](#快速开始)
3. [架构设计](#架构设计)
4. [项目结构](#项目结构)
5. [部署指南](#部署指南)
6. [部署检查清单](#部署检查清单)

---

## 项目概述

Share My Status macOS Client 是一个现代化的 macOS 应用程序，用于实时分享用户的状态信息（音乐、系统指标和活动）到 Share My Status 后端服务。

### 主要功能

- 🎵 **音乐检测** - 使用 MediaRemote Adapter 实时追踪音乐播放
- 💻 **系统监控** - CPU、内存和电池指标监控
- 👤 **活动检测** - 追踪用户当前工作内容
- 📤 **自动上报** - 可配置间隔的智能去重上报
- 🖼️ **专辑封面上传** - 自动检测和上传专辑封面

### 技术特点

- **现代 Swift 并发** - 使用 Actor 模式和 async/await
- **线程安全** - 所有后台服务使用 actor 隔离
- **类型安全** - 严格遵循后端 IDL 定义
- **现代 UI** - SwiftUI with @MainActor

---

## 快速开始

### 5分钟快速开始

#### 步骤 1: 编译MediaRemote Adapter (5分钟)

1. 克隆并编译 MediaRemote Adapter（支持 macOS 13.5+）:
   ```bash
   cd desktop/macos
   git clone https://github.com/ungive/mediaremote-adapter.git
   cd mediaremote-adapter
   mkdir build && cd build
   
   # 使用环境变量指定最低支持版本为 13.5
   MACOSX_DEPLOYMENT_TARGET=13.5 cmake ..
   cmake --build .
   ```

2. 验证编译结果（可选但推荐）:
   ```bash
   # 检查 framework 支持的最低版本
   otool -l build/MediaRemoteAdapter.framework/MediaRemoteAdapter | grep -A 5 LC_BUILD_VERSION
   # 应该看到 "minos 13.5"
   ```

3. 复制编译产物到项目目录:
   ```bash
   cd ../..
   cp mediaremote-adapter/bin/mediaremote-adapter.pl share-my-status-client/
   cp -r mediaremote-adapter/build/MediaRemoteAdapter.framework share-my-status-client/
   ```

> **注意**: 必须使用 `MACOSX_DEPLOYMENT_TARGET=13.5` 环境变量，否则编译出的 framework 只能在当前系统版本上运行，无法在 macOS 13.5 上使用。

#### 步骤 2: 配置Xcode (2分钟)

1. 打开项目:
   ```bash
   cd desktop/macos
   open share-my-status-client.xcodeproj
   ```

2. 将文件添加到项目:
   - 拖拽 `mediaremote-adapter.pl` 到Xcode (不添加到target)
   - 拖拽 `MediaRemoteAdapter.framework` 到Xcode (添加到target)

3. 配置Build Phases:
   - 选择target → Build Phases
   - 点击 "+" → New Copy Files Phase
   
   **添加第一个Copy Files Phase**:
   - Name: Copy MediaRemote Script
   - Destination: Resources
   - 添加 `mediaremote-adapter.pl`
   - ✓ Code Sign On Copy
   
   **添加第二个Copy Files Phase**:
   - Name: Copy MediaRemote Framework
   - Destination: Frameworks
   - 添加 `MediaRemoteAdapter.framework`
   - ✓ Code Sign On Copy

4. 设置Deployment Target:
   - Build Settings → 搜索 "Deployment"
   - macOS Deployment Target = 13.5

#### 步骤 3: 编译运行 (1分钟)

1. Clean Build Folder: `⌘ + Shift + K`
2. Build: `⌘ + B`
3. Run: `⌘ + R`

#### 步骤 3.1: 验证应用包内容

构建成功后，检查应用包内容：

```bash
# 进入构建产物目录
cd ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug

# 检查应用包结构
ls -la share-my-status-client.app/Contents/Resources/
# 应该看到: mediaremote-adapter.pl

ls -la share-my-status-client.app/Contents/Frameworks/
# 应该看到: MediaRemoteAdapter.framework/
```

#### 步骤 4: 配置应用

1. 应用启动后，菜单栏会出现图标
2. 点击图标 → "设置"
3. 配置:
   - 服务器地址: 你的backend URL
   - 密钥: 你的API密钥
   - 启用需要的功能
4. 返回状态页，点击"开始上报"

#### 步骤 5: 授权权限

**Accessibility权限** (活动检测需要):
1. 系统会自动弹出授权提示
2. 或手动: 系统设置 → 隐私与安全性 → 辅助功能
3. 添加并启用 "Share My Status"

### 验证工作正常

#### ✅ 检查清单

- [ ] 菜单栏显示应用图标
- [ ] 点击图标能看到菜单
- [ ] 播放音乐时显示歌曲信息
- [ ] 系统指标 (CPU/内存/电池) 显示
- [ ] 切换应用时活动标签更新
- [ ] "开始上报" 按钮可用
- [ ] 点击"立即上报"无错误
- [ ] Backend收到数据

### 🐛 故障排除

#### 常见错误 1: "File not found" 错误

**症状**: 构建时提示找不到 `mediaremote-adapter.pl` 或 `MediaRemoteAdapter.framework`

**解决方案**:
1. 确认已按照步骤1编译MediaRemote Adapter
2. 验证编译产物存在:
   ```bash
   ls -la mediaremote-adapter/bin/mediaremote-adapter.pl
   ls -la mediaremote-adapter/build/MediaRemoteAdapter.framework/
   ```
3. 确认文件已复制到 `share-my-status-client/` 目录
4. 确认文件已正确添加到Xcode项目

#### 常见错误 2: 代码签名错误

**症状**: 构建时提示代码签名失败

**解决方案**:
1. 确认在 Copy Files Phase 中勾选了 "Code Sign On Copy"
2. 检查开发者证书是否有效
3. 在 Build Settings 中检查 Code Signing 配置

#### 常见错误 3: Framework not found 错误

**症状**: 运行时提示找不到 MediaRemoteAdapter.framework

**解决方案**:
1. 确认 Framework 被复制到 Frameworks 目录
2. 检查 Framework 的架构是否匹配 (x86_64/arm64)
3. 确认 Framework 没有被链接 (不应该在 Link Binary With Libraries 中)

**看不到音乐信息？**
```bash
# 测试MediaRemote Adapter
cd ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug
./share-my-status-client.app/Contents/MacOS/share-my-status-client

# 或手动测试
/usr/bin/perl \
  ./share-my-status-client.app/Contents/Resources/mediaremote-adapter.pl \
  ./share-my-status-client.app/Contents/Frameworks/MediaRemoteAdapter.framework \
  get
```

**看不到活动信息？**
- 检查是否授予了Accessibility权限
- 系统设置 → 隐私与安全性 → 辅助功能

**无法上报？**
- 检查网络连接
- 验证URL和密钥配置正确
- 查看Console.app日志

---

## 架构设计

### 设计原则

1. **现代化架构** - 采用Swift现代并发特性
2. **线程安全** - Actor模式确保数据安全
3. **清晰分层** - UI、协调、服务、系统四层架构
4. **类型安全** - 严格类型定义，匹配backend IDL
5. **可测试性** - 依赖注入，协议抽象
6. **可维护性** - 清晰的职责分离

### 层次架构

```
┌─────────────────────────────────────┐
│           UI Layer                  │
│        (@MainActor)                 │
│  ┌─────────────┐ ┌─────────────┐   │
│  │ MenuBarView │ │ ContentView │   │
│  └─────────────┘ └─────────────┘   │
└─────────────────┬───────────────────┘
                  │
┌─────────────────┴───────────────────┐
│      Coordination Layer             │
│       (@MainActor)                  │
│  ┌─────────────┐ ┌─────────────┐   │
│  │StatusReport-│ │AppCoordinat-│   │
│  │     er      │ │     or      │   │
│  └─────────────┘ └─────────────┘   │
└─────────────────┬───────────────────┘
                  │
┌─────────────────┴───────────────────┐
│         Service Layer               │
│          (Actors)                   │
│ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐   │
│ │Media│ │Sys- │ │Act- │ │Net- │   │
│ │Rem- │ │Mon- │ │Det- │ │work │   │
│ │ote  │ │itor │ │ect  │ │Serv │   │
│ │Serv │ │Serv │ │Serv │ │ice  │   │
│ └─────┘ └─────┘ └─────┘ └─────┘   │
└─────────────────┬───────────────────┘
                  │
┌─────────────────┴───────────────────┐
│      System/External APIs           │
│                                     │
│ MediaRemote │ IOKit │ AppServices   │
│   Adapter   │       │               │
└─────────────────────────────────────┘
```

### 数据流

#### 配置流
```
User Input → SettingsTabView → AppConfiguration → Services
```

#### 状态流
```
System APIs → Services → StatusReporter → UI Components
```

#### 上报流
```
Services → StatusReporter → NetworkService → Backend API
```

### Actor服务

#### MediaRemoteService
- **职责**: 音乐信息检测和流式更新
- **线程**: Background actor
- **依赖**: MediaRemote Adapter
- **输出**: MusicSnapshot

#### SystemMonitorService  
- **职责**: 系统指标收集
- **线程**: Background actor
- **依赖**: IOKit
- **输出**: SystemSnapshot

#### ActivityDetectorService
- **职责**: 活动检测和分类
- **线程**: Background actor  
- **依赖**: ApplicationServices
- **输出**: ActivitySnapshot

#### NetworkService
- **职责**: API通信和错误处理
- **线程**: Background actor
- **依赖**: URLSession
- **输出**: 网络响应

#### CoverService
- **职责**: 封面管理和上传
- **线程**: Background actor
- **依赖**: NetworkService
- **输出**: coverHash

### 协调层

#### StatusReporter (@MainActor)
- **职责**: 状态收集和上报协调
- **特点**: 主线程ObservableObject
- **功能**: 
  - 并行收集各服务数据
  - 智能去重和缓存
  - 定时上报管理
  - UI状态更新

#### AppCoordinator (@MainActor)
- **职责**: 应用生命周期管理
- **功能**:
  - 服务初始化
  - 配置变更响应
  - 错误处理协调

### 线程安全

#### Actor隔离
- 所有服务使用actor自动同步
- 避免数据竞争和锁竞争
- 清晰的异步边界

#### MainActor UI
- 所有UI更新在主线程
- ObservableObject自动发布更新
- 避免UI线程阻塞

#### 异步通信
```swift
// 服务间通信
let music = try await mediaService.getCurrentMusic()

// UI更新
await MainActor.run {
    self.currentMusic = music
}
```

### 错误处理

#### 分层错误处理
```swift
// 服务层错误
enum MediaRemoteError: LocalizedError {
    case adapterNotFound
    case executionFailed(String)
}

// 协调层错误处理
do {
    let music = try await mediaService.getCurrentMusic()
} catch {
    logger.error("Music detection failed: \(error)")
    // 继续其他服务
}
```

#### 优雅降级
- 单个服务失败不影响其他功能
- 网络错误自动重试
- 用户友好的错误提示

### 性能考虑

#### 并发优化
```swift
// 并行数据收集
async let music = mediaService.getCurrentMusic()
async let system = systemService.getCurrentSnapshot()  
async let activity = activityService.getCurrentActivity()

let (m, s, a) = await (music, system, activity)
```

#### 内存管理
- Actor自动管理生命周期
- 弱引用避免循环引用
- Task取消机制

#### 缓存策略
- 智能去重避免重复上报
- 配置变更时清除缓存
- 内存敏感的图片缓存

### 兼容性

#### macOS版本支持
- **最低要求**: macOS 13.5
- **推荐版本**: macOS 14.0+
- **新特性**: 条件编译处理

#### 向后兼容
```swift
if #available(macOS 14.0, *) {
    // 使用新特性
    openWindow(id: "main")
} else {
    // 降级处理
    NSApp.activate(ignoringOtherApps: true)
}
```

### 测试策略

#### 单元测试
- Actor服务独立测试
- Mock依赖注入
- 异步测试支持

#### 集成测试
- 端到端数据流测试
- 网络层集成测试
- UI交互测试

#### 调试支持
- 结构化日志
- 性能指标收集
- 错误追踪

---

## 项目结构

### 文件树结构

```
share-my-status-client/
├── share_my_status_clientApp.swift     # 应用入口
├── ContentView.swift                   # 主窗口视图
├── MenuBarView.swift                   # 菜单栏视图
├── Models/                             # 数据模型
│   ├── API/                           # API相关模型
│   │   ├── APIModels.swift            # 基础API模型
│   │   ├── StateModels.swift          # 状态上报API
│   │   └── CoverModels.swift          # 封面API
│   ├── Domain/                        # 领域模型
│   │   ├── MusicModels.swift          # 音乐领域模型
│   │   ├── SystemModels.swift         # 系统领域模型
│   │   └── ActivityModels.swift       # 活动领域模型
│   └── Settings/                      # 设置模型
│       ├── AppConfiguration.swift     # 应用配置
│       └── DefaultSettings.swift      # 默认设置
├── Services/                          # 服务层
│   ├── Media/                         # 媒体服务
│   │   ├── MediaRemoteService.swift   # 音乐检测服务
│   │   ├── MediaRemoteTypes.swift     # MediaRemote类型
│   │   └── README.md                  # MediaRemote集成说明
│   ├── SystemMonitorService.swift     # 系统监控服务
│   ├── ActivityDetectorService.swift  # 活动检测服务
│   ├── NetworkService.swift           # 网络服务
│   └── CoverService.swift             # 封面管理服务
├── mediaremote-adapter.pl            # MediaRemote Perl脚本
└── MediaRemoteAdapter.framework/     # MediaRemote辅助框架
├── Core/                              # 核心层
│   ├── StatusReporter.swift           # 状态上报协调器
│   └── AppCoordinator.swift           # 应用协调器
├── Views/                             # 视图层
│   ├── MainWindow/                    # 主窗口
│   │   ├── StatusTabView.swift        # 状态标签页
│   │   └── SettingsTabView.swift      # 设置标签页
│   └── Components/                    # 组件
│       └── StatusIndicator.swift      # 状态指示器
├── Utilities/                         # 工具类
│   ├── Extensions/                    # 扩展
│   │   ├── Data+MD5.swift            # MD5计算扩展
│   │   └── Process+Async.swift       # Process异步封装
│   └── Logger.swift                   # 结构化日志
└── README.md                          # 项目说明
```

### 目录职责

#### Models/ - 数据模型层
- **API/**: 与后端API通信的模型，严格遵循IDL定义
- **Domain/**: 业务领域模型，应用内部使用
- **Settings/**: 应用配置和设置相关模型

#### Services/ - 服务层
- **Media/**: 音乐检测相关服务和类型
  - **MediaRemoteService**: Actor服务，使用 mediaremote-adapter 获取音乐信息
  - **MediaRemoteTypes**: MediaRemote 相关类型定义
  - **README.md**: MediaRemote 集成详细说明
- **SystemMonitorService**: 系统指标监控
- **ActivityDetectorService**: 用户活动检测
- **NetworkService**: 网络通信服务
- **CoverService**: 专辑封面管理

#### 外部依赖
- **mediaremote-adapter.pl**: Perl脚本，用于访问 macOS MediaRemote 框架
- **MediaRemoteAdapter.framework**: 辅助框架，提供 MediaRemote API 访问

#### Core/ - 核心协调层
- **StatusReporter**: 主要的状态收集和上报协调器
- **AppCoordinator**: 应用生命周期和服务管理

#### Views/ - 视图层
- **MainWindow/**: 主窗口的各个标签页
- **Components/**: 可复用的UI组件

#### Utilities/ - 工具层
- **Extensions/**: 有用的类型扩展
- **Logger**: 结构化日志工具

### 数据流

#### 配置数据流
```
用户输入 → SettingsTabView → AppConfiguration → 各个Services
```

#### 状态数据流
```
系统API → Services → StatusReporter → UI组件
```

#### 上报数据流
```
Services → StatusReporter → NetworkService → 后端API
```

### 线程模型

#### 主线程 (Main Thread)
- **UI更新**: 所有SwiftUI视图更新
- **用户交互**: 按钮点击、输入处理
- **协调器**: StatusReporter和AppCoordinator

#### 后台线程 (Background Threads)
- **服务Actor**: 所有Service都在后台线程运行
- **网络请求**: URLSession自动管理
- **文件IO**: 配置读写、日志写入

### 通信机制

#### Actor消息传递
```swift
// 异步调用服务
let music = try await mediaService.getCurrentMusic()
```

#### ObservableObject发布
```swift
@Published var currentStatus: StatusSnapshot?
```

#### Combine配置更新
```swift
configuration.$endpointURL
    .sink { url in
        // 更新网络服务配置
    }
```

### 依赖关系

#### 服务依赖
- **CoverService** → NetworkService
- **StatusReporter** → 所有Services
- **AppCoordinator** → StatusReporter

#### 模型依赖
- **API Models** ← Domain Models (转换)
- **Settings** → Services (配置)

### 文件统计

#### 代码行数统计
- **总文件数**: 30个
- **Swift代码**: ~3,500行
- **文档**: ~2,000行
- **配置**: ~200行

#### 按类型分布
- **Models**: 8个文件, ~800行
- **Services**: 6个文件, ~1,200行
- **Views**: 5个文件, ~900行
- **Core**: 2个文件, ~400行
- **Utilities**: 4个文件, ~200行

### 与旧架构对比

#### 旧架构问题
- 文件散乱，职责不清
- 线程安全问题
- 回调地狱
- 模型不匹配后端

#### 新架构优势
- 清晰的分层结构
- Actor保证线程安全
- async/await简化异步代码
- 严格遵循IDL定义

### 维护指南

#### 添加新功能
1. 在相应的Models/目录添加模型
2. 在Services/创建对应的Actor服务
3. 在StatusReporter中集成新服务
4. 在Views/添加UI组件

#### 修改现有功能
1. 确定影响范围（Models/Services/Views）
2. 更新相关的Actor服务
3. 测试线程安全性
4. 更新文档

#### 性能优化
1. 使用Instruments分析瓶颈
2. 优化Actor间通信
3. 减少主线程阻塞
4. 合理使用缓存

---

## 部署指南

### 系统要求

#### 开发环境
- **macOS**: 13.5 或更高版本
- **Xcode**: 15.0 或更高版本  
- **Swift**: 5.9 或更高版本

#### 运行环境
- **macOS**: 13.5 或更高版本
- **权限**: Accessibility (活动检测)
- **网络**: 访问后端API的网络连接

### 前置步骤

#### 1. 编译MediaRemote Adapter

克隆并编译 MediaRemote Adapter:

```bash
# 进入 macOS 桌面端目录
cd desktop/macos

# 克隆 mediaremote-adapter 仓库
git clone https://github.com/ungive/mediaremote-adapter.git

# 编译（指定最低支持 macOS 13.5）
cd mediaremote-adapter
mkdir build && cd build
MACOSX_DEPLOYMENT_TARGET=13.5 cmake ..
cmake --build .
cd ../..

# 复制编译产物到项目目录
cp mediaremote-adapter/bin/mediaremote-adapter.pl share-my-status-client/
cp -r mediaremote-adapter/build/MediaRemoteAdapter.framework share-my-status-client/
```

**重要说明**:
- 必须使用 `MACOSX_DEPLOYMENT_TARGET=13.5` 环境变量指定最低部署版本
- 如果不指定，编译出的 framework 将只支持当前系统版本
- 验证命令: `otool -l MediaRemoteAdapter.framework/MediaRemoteAdapter | grep -A 5 LC_BUILD_VERSION`
- 输出中应看到 `minos 13.5` 表示支持 macOS 13.5+

#### 2. 验证文件
确保以下文件存在于 `share-my-status-client/` 目录:
- `mediaremote-adapter.pl` (Perl脚本)
- `MediaRemoteAdapter.framework/` (Framework目录)

### Xcode项目配置

#### 步骤1: 添加文件到项目

1. 打开Xcode项目:
   ```bash
   open share-my-status-client.xcodeproj
   ```

2. 将文件拖拽到Xcode:
   - `mediaremote-adapter.pl` → 不添加到target
   - `MediaRemoteAdapter.framework` → 添加到target

#### 步骤2: 配置Build Phases

选择target → Build Phases → 点击"+" → New Copy Files Phase

**第一个Copy Files Phase**:
- **Name**: Copy MediaRemote Script
- **Destination**: Resources
- **Subpath**: (留空)
- **Files**: 添加 `mediaremote-adapter.pl`
- **✓ Code Sign On Copy**

**第二个Copy Files Phase**:
- **Name**: Copy MediaRemote Framework  
- **Destination**: Frameworks
- **Subpath**: (留空)
- **Files**: 添加 `MediaRemoteAdapter.framework`
- **✓ Code Sign On Copy**

#### 步骤3: 设置Deployment Target

Build Settings → 搜索 "Deployment":
- **macOS Deployment Target**: 13.5

#### 步骤4: 配置代码签名 (可选)

Build Settings → 搜索 "Code Signing":
- **Development Team**: 选择你的团队
- **Code Signing Identity**: Apple Development

### 构建应用

#### 命令行构建
```bash
cd desktop/macos

# Clean
xcodebuild clean -project share-my-status-client.xcodeproj

# Build Debug
xcodebuild -project share-my-status-client.xcodeproj \
           -scheme share-my-status-client \
           -configuration Debug \
           build

# Build Release
xcodebuild -project share-my-status-client.xcodeproj \
           -scheme share-my-status-client \
           -configuration Release \
           build
```

#### Xcode构建
1. 选择scheme: share-my-status-client
2. Clean Build Folder: `⌘ + Shift + K`
3. Build: `⌘ + B`

### 分发选项

#### 选项1: 直接分发
```bash
# 构建后的应用位置
~/Library/Developer/Xcode/DerivedData/*/Build/Products/Release/share-my-status-client.app

# 打包为DMG (可选)
hdiutil create -volname "Share My Status" \
               -srcfolder share-my-status-client.app \
               -ov -format UDZO \
               share-my-status-client.dmg
```

#### 选项2: App Store分发
1. 配置App Store Connect
2. 设置Provisioning Profile
3. Archive: Product → Archive
4. Upload to App Store

#### 选项3: 公证分发
```bash
# 导出应用
xcodebuild -exportArchive \
           -archivePath share-my-status-client.xcarchive \
           -exportPath ./export \
           -exportOptionsPlist ExportOptions.plist

# 公证 (需要Apple ID)
xcrun notarytool submit share-my-status-client.app.zip \
                      --apple-id your@email.com \
                      --password app-specific-password \
                      --team-id TEAM_ID
```

### 验证脚本

可以使用以下脚本自动验证配置是否正确：

```bash
#!/bin/bash

APP_PATH="$1"
if [ -z "$APP_PATH" ]; then
    echo "使用方法: $0 <应用路径>"
    exit 1
fi

echo "验证 MediaRemote 配置..."

# 检查脚本文件
SCRIPT_PATH="$APP_PATH/Contents/Resources/mediaremote-adapter.pl"
if [ -f "$SCRIPT_PATH" ]; then
    echo "✅ mediaremote-adapter.pl 存在"
    if [ -x "$SCRIPT_PATH" ]; then
        echo "✅ mediaremote-adapter.pl 可执行"
    else
        echo "❌ mediaremote-adapter.pl 不可执行"
    fi
else
    echo "❌ mediaremote-adapter.pl 不存在"
fi

# 检查 Framework
FRAMEWORK_PATH="$APP_PATH/Contents/Frameworks/MediaRemoteAdapter.framework"
if [ -d "$FRAMEWORK_PATH" ]; then
    echo "✅ MediaRemoteAdapter.framework 存在"
    
    # 检查架构
    BINARY_PATH="$FRAMEWORK_PATH/MediaRemoteAdapter"
    if [ -f "$BINARY_PATH" ]; then
        echo "✅ Framework 二进制文件存在"
        echo "架构信息:"
        lipo -info "$BINARY_PATH"
    else
        echo "❌ Framework 二进制文件不存在"
    fi
else
    echo "❌ MediaRemoteAdapter.framework 不存在"
fi

# 检查代码签名
echo "检查代码签名..."
codesign -v "$APP_PATH" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ 应用签名有效"
else
    echo "❌ 应用签名无效"
fi

echo "验证完成"
```

使用方法：
```bash
chmod +x verify_setup.sh
./verify_setup.sh ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/share-my-status-client.app
```

### 高级配置

#### 自定义构建脚本

如果需要更复杂的配置，可以添加 Run Script Phase：

1. 选择 target → Build Phases → 点击 "+" → New Run Script Phase
2. 设置脚本内容：

```bash
#!/bin/bash

# 确保 MediaRemote 文件存在
SCRIPT_PATH="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/mediaremote-adapter.pl"
FRAMEWORK_PATH="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Frameworks/MediaRemoteAdapter.framework"

if [ ! -f "$SCRIPT_PATH" ]; then
    echo "错误: mediaremote-adapter.pl 未找到"
    exit 1
fi

if [ ! -d "$FRAMEWORK_PATH" ]; then
    echo "错误: MediaRemoteAdapter.framework 未找到"
    exit 1
fi

# 设置执行权限
chmod +x "$SCRIPT_PATH"

echo "MediaRemote 配置验证完成"
```

#### 条件编译

可以使用条件编译来处理不同的构建配置：

```swift
#if DEBUG
private let mediaRemoteEnabled = true
#else
private let mediaRemoteEnabled = true
#endif
```

### 故障排除

#### 问题诊断步骤

1. **检查文件存在性**:
   ```bash
   find ~/Library/Developer/Xcode/DerivedData -name "mediaremote-adapter.pl"
   find ~/Library/Developer/Xcode/DerivedData -name "MediaRemoteAdapter.framework"
   ```

2. **检查权限**:
   ```bash
   ls -la ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/*.app/Contents/Resources/mediaremote-adapter.pl
   ```

3. **测试 MediaRemote**:
   ```bash
   /usr/bin/perl /path/to/mediaremote-adapter.pl /path/to/MediaRemoteAdapter.framework test
   ```

#### MediaRemote相关问题

**问题**: 找不到MediaRemote Adapter
```bash
# 检查文件是否正确复制
ls -la ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/share-my-status-client.app/Contents/Resources/
ls -la ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/share-my-status-client.app/Contents/Frameworks/
```

**问题**: MediaRemote权限被拒绝
```bash
# 手动测试脚本
cd ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/
/usr/bin/perl \
  ./share-my-status-client.app/Contents/Resources/mediaremote-adapter.pl \
  ./share-my-status-client.app/Contents/Frameworks/MediaRemoteAdapter.framework \
  get
```

#### Accessibility权限问题

**问题**: 活动检测不工作
1. 系统设置 → 隐私与安全性 → 辅助功能
2. 添加 "Share My Status" 应用
3. 确保开关已启用

**问题**: 权限提示不出现
```bash
# 重置权限数据库
sudo tccutil reset Accessibility com.share-my-status.client
```

#### 代码签名问题

**问题**: 代码签名失败
```bash
# 检查签名状态
codesign -vvv --deep --strict share-my-status-client.app

# 重新签名
codesign --force --deep --sign "Apple Development" share-my-status-client.app
```

**问题**: Gatekeeper阻止运行
```bash
# 临时允许运行 (仅用于测试)
sudo spctl --master-disable

# 或为特定应用添加例外
sudo spctl --add share-my-status-client.app
```

#### 常见问题解决

1. **权限被拒绝**: 确保脚本有执行权限
   ```bash
   chmod +x /path/to/mediaremote-adapter.pl
   ```

2. **Framework 加载失败**: 检查架构匹配
   ```bash
   lipo -info MediaRemoteAdapter.framework/MediaRemoteAdapter
   ```

3. **代码签名问题**: 重新配置开发者证书
   ```bash
   codesign --force --deep --sign "Apple Development" share-my-status-client.app
   ```

4. **路径问题**: 使用绝对路径测试
   ```bash
   /usr/bin/perl /absolute/path/to/mediaremote-adapter.pl /absolute/path/to/MediaRemoteAdapter.framework get
   ```

### 最佳实践

#### 开发建议
1. **版本控制**: 不要将二进制文件（.framework, .pl）和 mediaremote-adapter 仓库提交到 Git
   - 在 `.gitignore` 中添加：
     ```
     *.framework
     mediaremote-adapter.pl
     mediaremote-adapter/
     ```

2. **自动化**: 使用一键编译脚本自动编译和配置依赖
   ```bash
   #!/bin/bash
   # 一键编译 MediaRemote Adapter 依赖
   
   set -e  # 遇到错误立即退出
   
   cd desktop/macos
   
   # 克隆仓库（如果不存在）
   if [ ! -d "mediaremote-adapter" ]; then
       echo "克隆 mediaremote-adapter 仓库..."
       git clone https://github.com/ungive/mediaremote-adapter.git
   else
       echo "更新 mediaremote-adapter..."
       cd mediaremote-adapter
       git pull
       cd ..
   fi
   
   # 编译（指定支持 macOS 13.5+）
   echo "编译 MediaRemote Adapter..."
   cd mediaremote-adapter
   mkdir -p build && cd build
   MACOSX_DEPLOYMENT_TARGET=13.5 cmake ..
   cmake --build .
   cd ../..
   
   # 复制到项目目录
   echo "复制文件到项目目录..."
   cp mediaremote-adapter/bin/mediaremote-adapter.pl share-my-status-client/
   cp -r mediaremote-adapter/build/MediaRemoteAdapter.framework share-my-status-client/
   
   echo "✅ 编译完成！"
   echo "编译产物已复制到 share-my-status-client/ 目录"
   ```
   
   保存为 `build_dependencies.sh` 并执行:
   ```bash
   chmod +x build_dependencies.sh
   ./build_dependencies.sh
   ```

3. **文档维护**: 保持配置文档更新
   - 记录使用的版本号
   - 更新配置步骤
   - 记录已知问题

4. **环境测试**: 在不同环境中测试配置
   - Debug 和 Release 构建
   - 不同 macOS 版本
   - Intel 和 Apple Silicon

### 更新流程

#### 应用更新
1. 修改版本号: Info.plist → CFBundleShortVersionString
2. 重新构建和签名
3. 分发新版本

#### MediaRemote Adapter更新
1. 进入 mediaremote-adapter 目录
2. 拉取最新代码: `git pull`
3. 重新编译（保持版本兼容性）:
   ```bash
   cd build
   rm -rf *  # 清理旧的构建文件
   MACOSX_DEPLOYMENT_TARGET=13.5 cmake ..
   cmake --build .
   ```
4. 复制新的编译产物到项目目录:
   ```bash
   cp ../bin/mediaremote-adapter.pl ../../share-my-status-client/
   cp -r MediaRemoteAdapter.framework ../../share-my-status-client/
   ```
5. 重新构建应用

### 验证部署

#### 功能测试清单
- [ ] 应用正常启动
- [ ] 菜单栏图标显示
- [ ] 音乐检测工作
- [ ] 系统指标显示
- [ ] 活动检测工作
- [ ] 网络上报成功
- [ ] 设置保存正常

#### 性能测试
```bash
# 监控CPU使用
top -pid $(pgrep share-my-status-client)

# 监控内存使用
vmmap $(pgrep share-my-status-client)

# 查看日志
log stream --predicate 'subsystem == "com.share-my-status.client"'
```

---
## 部署检查清单

### 必需步骤 (Mandatory)

#### MediaRemote Adapter 集成
- [ ] **编译 MediaRemote Adapter**
  - [ ] 克隆仓库: `git clone https://github.com/ungive/mediaremote-adapter.git`
  - [ ] 创建构建目录: `mkdir build && cd build`
  - [ ] 运行 CMake（指定最低版本）: `MACOSX_DEPLOYMENT_TARGET=13.5 cmake ..`
  - [ ] 编译: `cmake --build .`
  - [ ] 验证编译产物: `mediaremote-adapter.pl` 和 `MediaRemoteAdapter.framework`
  - [ ] 检查 framework 支持的版本: `otool -l MediaRemoteAdapter.framework/MediaRemoteAdapter | grep -A 5 LC_BUILD_VERSION`（应看到 `minos 13.5`）
  - [ ] 复制文件到项目目录 `share-my-status-client/`

- [ ] **添加文件到 Xcode 项目**
  - [ ] 将 `mediaremote-adapter.pl` 拖拽到项目 (不添加到target)
  - [ ] 将 `MediaRemoteAdapter.framework` 拖拽到项目 (添加到target)
  - [ ] 确认文件在项目导航器中正确显示

#### Xcode 项目配置
- [ ] **配置 Build Phases**
  - [ ] 添加 "Copy MediaRemote Script" Copy Files Phase
    - [ ] Destination: Resources
    - [ ] 添加 `mediaremote-adapter.pl`
    - [ ] ✓ Code Sign On Copy
  - [ ] 添加 "Copy MediaRemote Framework" Copy Files Phase
    - [ ] Destination: Frameworks  
    - [ ] 添加 `MediaRemoteAdapter.framework`
    - [ ] ✓ Code Sign On Copy

- [ ] **设置 Deployment Target**
  - [ ] Build Settings → macOS Deployment Target = 13.5
  - [ ] 验证所有依赖库支持该版本

- [ ] **验证编译**
  - [ ] Clean Build Folder (`⌘ + Shift + K`)
  - [ ] Build (`⌘ + B`) - 确保无编译错误
  - [ ] 检查 Build 日志中的警告信息

### 推荐步骤 (Recommended)

#### 代码质量检查
- [ ] **静态分析**
  - [ ] 运行 Xcode Static Analyzer
  - [ ] 检查并修复所有警告
  - [ ] 验证内存管理正确性

- [ ] **代码风格**
  - [ ] 运行 SwiftLint (如果配置)
  - [ ] 检查代码格式一致性
  - [ ] 验证命名规范

#### 功能测试
- [ ] **音乐检测测试**
  - [ ] 启动应用，播放音乐
  - [ ] 验证菜单栏显示当前播放信息
  - [ ] 测试不同音乐应用 (Music, Spotify, etc.)
  - [ ] 验证暂停/播放状态更新

- [ ] **系统监控测试**
  - [ ] 验证 CPU 使用率显示
  - [ ] 验证内存使用率显示
  - [ ] 验证电池状态显示 (笔记本)
  - [ ] 测试数据更新频率

- [ ] **活动检测测试**
  - [ ] 切换不同应用程序
  - [ ] 验证活动标签更新
  - [ ] 测试 Accessibility 权限
  - [ ] 验证应用黑名单功能

- [ ] **网络上报测试**
  - [ ] 配置有效的服务器 URL 和 API 密钥
  - [ ] 点击"立即上报"验证网络连接
  - [ ] 检查后端是否收到数据
  - [ ] 测试网络错误处理

### 故障排除 (Troubleshooting)

#### MediaRemote 相关问题
- [ ] **Adapter 未找到**
  ```bash
  # 检查文件是否正确复制
  ls -la ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/share-my-status-client.app/Contents/Resources/mediaremote-adapter.pl
  ls -la ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/share-my-status-client.app/Contents/Frameworks/MediaRemoteAdapter.framework
  ```

- [ ] **权限问题**
  ```bash
  # 手动测试 MediaRemote Adapter
  cd ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/
  /usr/bin/perl \
    ./share-my-status-client.app/Contents/Resources/mediaremote-adapter.pl \
    ./share-my-status-client.app/Contents/Frameworks/MediaRemoteAdapter.framework \
    get
  ```

#### Accessibility 权限问题
- [ ] **权限未授予**
  - [ ] 系统设置 → 隐私与安全性 → 辅助功能
  - [ ] 添加 "Share My Status" 应用
  - [ ] 确保开关已启用

- [ ] **权限提示未出现**
  ```bash
  # 重置权限数据库
  sudo tccutil reset Accessibility com.share-my-status.client
  ```

#### 代码签名问题
- [ ] **签名失败**
  ```bash
  # 检查签名状态
  codesign -vvv --deep --strict share-my-status-client.app
  
  # 重新签名
  codesign --force --deep --sign "Apple Development" share-my-status-client.app
  ```

### 完成检查清单 (Completion Checklist)

#### 基本功能验证
- [ ] 应用正常启动，无崩溃
- [ ] 菜单栏图标正确显示
- [ ] 主窗口可以正常打开和关闭
- [ ] 设置页面所有控件正常工作

#### 核心功能验证
- [ ] 音乐信息正确显示和更新
- [ ] 系统指标准确显示
- [ ] 活动检测正常工作
- [ ] 网络上报成功执行

#### 用户体验验证
- [ ] 界面响应流畅，无明显延迟
- [ ] 错误信息清晰易懂
- [ ] 设置保存和恢复正常
- [ ] 应用退出和重启状态保持

#### 性能验证
- [ ] CPU 使用率合理 (< 5% 空闲时)
- [ ] 内存使用稳定 (< 100MB)
- [ ] 无明显内存泄漏
- [ ] 网络请求响应及时

#### 兼容性验证
- [ ] 在 macOS 13.5 上正常运行
- [ ] 在 macOS 14.0+ 上正常运行
- [ ] 不同屏幕分辨率下显示正常
- [ ] 深色/浅色模式切换正常

### 部署后验证

#### 用户反馈收集
- [ ] 设置用户反馈渠道
- [ ] 监控崩溃报告
- [ ] 收集性能数据
- [ ] 跟踪功能使用情况

#### 持续监控
- [ ] 监控后端 API 调用成功率
- [ ] 跟踪应用启动成功率
- [ ] 监控权限授予率
- [ ] 收集用户满意度数据

---

## 结语

本文档整合了 Share My Status macOS 客户端的完整技术文档，涵盖了从快速开始到深度架构设计的所有内容。项目已完成现代化重构，采用最新的 Swift 并发特性，提供稳定可靠的用户状态分享功能。

如需了解特定部分的详细信息，请参考相应章节。如有问题或建议，欢迎反馈。

**享受使用！** 🎉
