# 部署前检查清单

## ⚠️ 必须完成的步骤

### 1. MediaRemote Adapter 集成

- [ ] 下载 `mediaremote-adapter.pl` (最新版本)
  - 来源: https://github.com/ungive/mediaremote-adapter/releases
  - 放置位置: 项目根目录或直接添加到Xcode

- [ ] 下载 `MediaRemoteAdapter.framework` (最新版本)
  - 来源: https://github.com/ungive/mediaremote-adapter/releases
  - 放置位置: 项目根目录或直接添加到Xcode

- [ ] 添加文件到Xcode项目
  - 将两个文件拖入Xcode
  - `mediaremote-adapter.pl` 不要添加到target
  - `MediaRemoteAdapter.framework` 添加到target

- [ ] 配置Build Phases (重要！)
  - Target → Build Phases → "+" → New Copy Files Phase
  - **Phase 1 (Copy Script)**:
    - Destination: Resources
    - 添加 `mediaremote-adapter.pl`
    - ✓ Code Sign On Copy
  - **Phase 2 (Copy Framework)**:
    - Destination: Frameworks
    - 添加 `MediaRemoteAdapter.framework`
    - ✓ Code Sign On Copy

### 2. Xcode 项目配置

- [ ] 设置 Deployment Target
  - Build Settings → `MACOSX_DEPLOYMENT_TARGET` = `13.5`

- [ ] 验证 Swift Version
  - Build Settings → `SWIFT_VERSION` = `5.0` (或更高)

- [ ] 配置 Code Signing
  - Signing & Capabilities → Team → 选择你的开发团队
  - Automatically manage signing (推荐)

- [ ] 启用必要的 Capabilities
  - ✓ App Sandbox
  - ✓ Hardened Runtime
  - ✓ Outgoing Connections (Network)

### 3. 验证编译

- [ ] Clean Build Folder (⌘+Shift+K)
- [ ] Build for Running (⌘+B)
- [ ] 解决所有编译错误和警告
- [ ] Run (⌘+R) 并测试基本功能

## 📋 可选但推荐的步骤

### 代码质量

- [ ] 运行 SwiftLint (如果配置了)
- [ ] 检查所有警告
- [ ] 验证内存泄漏 (Instruments)

### 功能测试

- [ ] 测试音乐检测
  - 播放音乐 (Apple Music, Spotify等)
  - 验证菜单栏显示正确信息
  
- [ ] 测试系统监控
  - 检查CPU/内存/电池显示
  - 验证数据准确性

- [ ] 测试活动检测
  - 切换不同应用
  - 验证活动标签正确

- [ ] 测试上报功能
  - 配置backend URL和密钥
  - 点击"立即上报"
  - 检查backend是否收到数据

### 权限请求

- [ ] 测试Accessibility权限请求
  - 首次运行应提示授权
  - 在系统设置中验证

- [ ] 测试网络权限
  - 应能正常访问backend

## 🔍 故障排查

### 编译失败

**错误**: `Cannot find type 'XXX' in scope`
- 检查是否所有新文件都已添加到target
- Clean Build Folder后重新编译

**错误**: `Use of unresolved identifier`
- 检查import语句
- 验证文件在正确的目录结构中

### MediaRemote 不工作

**症状**: 没有音乐信息显示

1. 检查文件是否存在:
   ```bash
   ls -la "build/Debug/share-my-status-client.app/Contents/Resources/mediaremote-adapter.pl"
   ls -la "build/Debug/share-my-status-client.app/Contents/Frameworks/MediaRemoteAdapter.framework"
   ```

2. 手动测试adapter:
   ```bash
   /usr/bin/perl \
     "build/Debug/share-my-status-client.app/Contents/Resources/mediaremote-adapter.pl" \
     "build/Debug/share-my-status-client.app/Contents/Frameworks/MediaRemoteAdapter.framework" \
     get
   ```

3. 检查Console.app日志:
   - 过滤: `subsystem:com.wujunyi792.share-my-status-client`
   - 查找 MediaRemote 相关错误

### 网络请求失败

**症状**: 上报失败

1. 验证配置:
   - URL格式正确 (https://...)
   - API密钥非空
   - 网络已连接

2. 测试endpoint:
   ```bash
   curl -X POST https://your-backend/api/v1/state/report \
        -H "Authorization: Bearer YOUR_KEY" \
        -H "Content-Type: application/json" \
        -d '{"events":[]}'
   ```

3. 检查防火墙:
   - 系统设置 → 防火墙
   - 确保应用有网络访问权限

## ✅ 完成标志

所有检查项完成后，你应该能够:

- ✅ 成功编译应用
- ✅ 看到菜单栏图标
- ✅ 检测到正在播放的音乐
- ✅ 显示系统指标
- ✅ 检测活动标签
- ✅ 成功上报到backend
- ✅ 在backend看到数据

## 📚 参考文档

- `README.md` - 项目概述
- `ARCHITECTURE.md` - 架构详解
- `DEPLOYMENT.md` - 部署指南
- `MIGRATION.md` - 迁移指南
- `Services/Media/README.md` - MediaRemote集成

## 🆘 获取帮助

遇到问题？

1. 查看相关文档 (上述参考文档)
2. 检查Console.app日志
3. 参考MediaRemote Adapter项目的issues
4. 在项目仓库提交issue

---

**祝部署顺利！** 🎉

