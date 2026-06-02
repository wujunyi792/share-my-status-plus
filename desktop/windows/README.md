# Share My Status — Windows 客户端

Windows 桌面客户端，采集本机的**音乐播放、系统指标、前台活动**并上报到后端，
与 macOS 客户端共用同一套上报协议（`idl/` 下的 Thrift 契约）和后端服务。

- 语言/框架：**.NET 8 + WPF**（设置窗口） + **WinForms NotifyIcon**（系统托盘）
- 音乐采集：**Windows System Media Transport Controls (GSMTC)** —— 官方公共 API，
  免授权，覆盖 Spotify / 网易云 / QQ 音乐 / 浏览器内播放 / 系统播放器等
- 系统/活动采集：Win32 P/Invoke（`GetSystemPowerStatus` / `GlobalMemoryStatusEx` /
  `GetSystemTimes` / `GetForegroundWindow` / `GetLastInputInfo`）
- 零重型第三方依赖

### 交互与体验

- **首次运行引导**：未配置时自动弹出设置窗口。
- **测试连接**：填好地址/密钥后一键校验（命中 `/api/v1/client/resources`）。
- **应用选择器**：白名单与活动分组都可「从运行中的应用选择…」，无需手敲 exe 名；
  音乐白名单还会列出当前媒体源（🎵 标记）。
- **托盘提示**：tooltip 实时显示当前播放/系统/活动摘要；启动/停止/上报出错有气泡通知。
- **快捷入口**：托盘菜单可「打开我的状态页 / 自定义飞书签名」（由服务端 `client/resources`
  返回的链接驱动）、「检查更新」（打开 GitHub Releases）、「关于」、「打开日志文件夹」。

## 目录结构

```
desktop/windows/
├── ShareMyStatus.sln
└── ShareMyStatusClient/
    ├── ShareMyStatusClient.csproj      # net8.0-windows10.0.19041.0, WPF + WinForms
    ├── app.manifest                    # Per-monitor DPI + Win10/11 兼容声明
    ├── App.xaml / App.xaml.cs          # 托盘宿主 + 协调器（≈ macOS AppCoordinator）
    ├── Interop/
    │   └── NativeMethods.cs            # Win32 P/Invoke
    ├── Models/
    │   ├── Api/ApiModels.cs            # 上报/封面 等 API 模型（对齐 idl/common.thrift）
    │   ├── Domain/DomainModels.cs      # 采集快照 + 转换 + ActivityGroup
    │   └── Settings/
    │       ├── AppConfiguration.cs     # %APPDATA%\ShareMyStatus\config.json 持久化
    │       └── DefaultSettings.cs      # Windows 进程名 / 媒体源默认映射
    ├── Services/
    │   ├── NetworkService.cs           # HTTP 上报（X-Secret-Key）
    │   ├── CoverService.cs             # 封面 MD5 去重 + 上传
    │   ├── SystemMonitorService.cs     # 电池 / CPU(差分) / 内存
    │   ├── ActivityDetectorService.cs  # 前台进程 → 标签 + 空闲时长
    │   ├── MediaSessionService.cs      # GSMTC 事件驱动音乐采集
    │   ├── StatusReporter.cs           # 采集协调 + 去重 + 上报节奏
    │   └── AutostartService.cs         # 注册表 Run 键开机自启
    └── Views/
        ├── SettingsWindow.xaml(.cs)    # 设置界面（服务器/开关/间隔/白名单/分组/导入导出）
        └── ActivityGroupEditModel.cs   # 活动分组编辑模型
```

## 采集与上报行为（与 macOS 对齐）

| 模块 | 方式 | 字段 | Windows 实现 |
|------|------|------|-------------|
| 系统 | 轮询（默认 10s） | `batteryPct`(0–1) / `charging` / `cpuPct`(0–1) / `memoryPct`(0–1) | `GetSystemPowerStatus` / `GetSystemTimes` 差分 / `GlobalMemoryStatusEx` |
| 活动 | 轮询（默认 5s，标签去重） | `label` | 前台窗口 → 进程 exe 名 → 分组标签；空闲用 `GetLastInputInfo` |
| 音乐 | 事件驱动（换歌才上报） | `title` / `artist` / `album` / `coverHash` | GSMTC `MediaPropertiesChanged` / `PlaybackInfoChanged` + 缩略图 |

- **隐私**：窗口标题仅本地用于显示，**绝不上报**；上报仅含映射后的标签。
- **应用标识**：macOS 用 bundle id；Windows 用**进程可执行名**（如 `chrome.exe`）作活动标识，
  用媒体源 **SourceAppUserModelId**（如 `Spotify.exe`）作音乐白名单。两者均大小写不敏感。
- **封面去重**：取原始图片字节的小写十六进制 MD5（与后端、macOS 完全一致），
  先 `cover/exists` 再按需 `cover/upload`。
- **幂等**：每个事件携带 `idempotencyKey`（GUID），服务端去重。

## 配置

配置存于 `%APPDATA%\ShareMyStatus\config.json`，日志在 `%APPDATA%\ShareMyStatus\logs\app.log`。
首次运行需在托盘图标 → **设置** 中填写：

- **服务器地址**：完整上报 Endpoint，例如 `https://your-server/api/v1/state/report`
- **Secret Key**：上报密钥（请求头 `X-Secret-Key`）

随后可调整三个上报开关、采样间隔、音乐白名单、活动分组，并支持配置导入/导出与开机自启。

## 本地构建与运行

需要 [.NET 8 SDK](https://dotnet.microsoft.com/download)（仅 Windows 可构建，因依赖 WPF/WinRT）。

```powershell
cd desktop/windows
dotnet build ShareMyStatus.sln -c Release
dotnet run --project ShareMyStatusClient/ShareMyStatusClient.csproj
```

发布自包含单文件（无需目标机安装 .NET 运行时）：

```powershell
dotnet publish ShareMyStatusClient/ShareMyStatusClient.csproj `
  -c Release -r win-x64 --self-contained true `
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true `
  -o publish
```

运行 `publish/ShareMyStatus.exe`，应用以系统托盘常驻（无主窗口）。

## 发布（CI）

bump 根目录 `release.yml` 的 `windows: <marketingVersion-buildNumber>`（如 `1.0-2`），
然后手动触发 GitHub Actions 工作流 **“Manual Windows Client Build & Release”**
（`.github/workflows/windows-client-release.yml`）。CI 会自包含发布、打 zip 并创建
`desktop-windows-v<version>-<build>` 的 GitHub Release。

## 路线图 / 已知限制

- **代码签名**：当前未做 Authenticode 签名（首次运行会有 SmartScreen 提示）。
  后续可像 macOS 那样在 CI 注入证书 secret 进行签名。
- **自动更新**：目前为「检查更新」菜单打开 GitHub Releases 手动下载；
  可后续接入 Velopack / Squirrel 实现类 Sparkle 的静默更新。
- 不同播放器对 GSMTC 的支持程度不一，少数播放器可能不暴露会话信息。
- 仅支持 win-x64；如需 arm64 可在发布 RID 中追加。
- `electron` 类应用的前台进程名可能是其框架壳名，必要时按需在活动分组中补充。
```
