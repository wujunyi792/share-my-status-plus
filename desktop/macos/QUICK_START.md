# Quick Start Guide - macOS Client

## 5分钟快速开始

### 步骤 1: 准备MediaRemote Adapter (2分钟)

1. 访问 https://github.com/ungive/mediaremote-adapter/releases
2. 下载最新版本:
   - `mediaremote-adapter.pl`
   - `MediaRemoteAdapter.framework`
3. 将这两个文件放到项目根目录

### 步骤 2: 配置Xcode (2分钟)

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

### 步骤 3: 编译运行 (1分钟)

1. Clean Build Folder: `⌘ + Shift + K`
2. Build: `⌘ + B`
3. Run: `⌘ + R`

### 步骤 4: 配置应用

1. 应用启动后，菜单栏会出现图标
2. 点击图标 → "设置"
3. 配置:
   - 服务器地址: 你的backend URL
   - 密钥: 你的API密钥
   - 启用需要的功能
4. 返回状态页，点击"开始上报"

### 步骤 5: 授权权限

**Accessibility权限** (活动检测需要):
1. 系统会自动弹出授权提示
2. 或手动: 系统设置 → 隐私与安全性 → 辅助功能
3. 添加并启用 "Share My Status"

## 验证工作正常

### ✅ 检查清单

- [ ] 菜单栏显示应用图标
- [ ] 点击图标能看到菜单
- [ ] 播放音乐时显示歌曲信息
- [ ] 系统指标 (CPU/内存/电池) 显示
- [ ] 切换应用时活动标签更新
- [ ] "开始上报" 按钮可用
- [ ] 点击"立即上报"无错误
- [ ] Backend收到数据

### 🐛 故障排除

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

## 命令行快速测试

### 构建
```bash
cd desktop/macos
xcodebuild -project share-my-status-client.xcodeproj \
           -scheme share-my-status-client \
           -configuration Debug \
           build
```

### 运行
```bash
open build/Debug/share-my-status-client.app
```

### 查看日志
```bash
log stream --predicate 'subsystem == "com.wujunyi792.share-my-status-client"' --level debug
```

## 配置示例

### 开发环境
```
Server URL: http://localhost:8080/api/v1/state/report
API Key: dev-test-key-12345
Report Interval: 10秒
```

### 生产环境
```
Server URL: https://api.yourdomain.com/api/v1/state/report
API Key: prod-xxxxxxxxxxxxxxxx
Report Interval: 30秒
```

## 下一步

- 📖 阅读 [README.md](share-my-status-client/README.md) 了解详细功能
- 🏗 阅读 [ARCHITECTURE.md](ARCHITECTURE.md) 了解架构设计
- 🚀 阅读 [DEPLOYMENT.md](DEPLOYMENT.md) 了解部署流程
- 📝 阅读 [CHECKLIST.md](CHECKLIST.md) 完整部署检查

## 常用操作

### 开启/关闭上报
- 菜单栏图标 → "开始上报" / "停止上报"

### 立即上报一次
- 菜单栏图标 → "立即上报"

### 修改配置
- 菜单栏图标 → "设置"

### 查看状态
- 菜单栏图标 → "设置" → "状态" 标签

### 退出应用
- 菜单栏图标 → "退出"

---

**享受使用！** 🎉

