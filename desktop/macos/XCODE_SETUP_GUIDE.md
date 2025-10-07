# Xcode配置详细操作指南

## 前提条件

✅ 你已经下载并放置了这两个文件在项目根目录:
- `mediaremote-adapter.pl`
- `MediaRemoteAdapter.framework`

## 第一步: 添加文件到Xcode项目

### 1. 打开Xcode项目

```bash
cd /Users/bytedance/Codespace/share-my-status-plus/desktop/macos
open share-my-status-client.xcodeproj
```

### 2. 添加文件到项目

#### 2.1 添加Perl脚本

1. 在Xcode左侧导航器中，右键点击项目根目录 (或 `share-my-status-client` 文件夹)
2. 选择 **"Add Files to 'share-my-status-client'..."**
3. 在文件选择器中:
   - 导航到你放置文件的位置
   - 选中 `mediaremote-adapter.pl`
   - **重要**: 在底部选项中:
     - ✅ 勾选 "Copy items if needed"
     - ❌ **不要**勾选 "Add to targets" (取消target勾选框)
     - "Added folders": 选择 "Create groups"
   - 点击 "Add"

#### 2.2 添加Framework

1. 在Xcode左侧导航器中，右键点击项目根目录
2. 选择 **"Add Files to 'share-my-status-client'..."**
3. 在文件选择器中:
   - 选中 `MediaRemoteAdapter.framework` (整个文件夹)
   - **重要**: 在底部选项中:
     - ✅ 勾选 "Copy items if needed"
     - ✅ **勾选** "Add to targets: share-my-status-client"
     - "Added folders": 选择 "Create groups"
   - 点击 "Add"

## 第二步: 配置Build Phases

### 1. 打开Build Phases

1. 在Xcode左侧导航器中，点击最顶部的**项目图标** (蓝色的)
2. 在中间栏选择 **TARGETS** 下的 **"share-my-status-client"**
3. 点击顶部的 **"Build Phases"** 标签

### 2. 添加Copy Files Phase (脚本)

#### 2.1 创建新的Copy Files Phase

1. 在Build Phases页面，点击左上角的 **"+"** 按钮
2. 从下拉菜单选择 **"New Copy Files Phase"**
3. 会出现一个新的 "Copy Files" 区域

#### 2.2 配置Copy Files Phase (脚本)

1. 点击新创建的 "Copy Files" 左侧的三角形展开
2. 配置选项:
   - **Destination**: 点击下拉菜单，选择 **"Resources"**
   - **Subpath**: 留空
   - **Copy only when installing**: 取消勾选
   - **Code Sign On Copy**: ✅ **勾选**

3. 添加脚本文件:
   - 点击 Copy Files 下方的 **"+"** 按钮
   - 在弹出的文件列表中找到 `mediaremote-adapter.pl`
   - 选中它，点击 **"Add"**

4. 重命名此Phase (可选但推荐):
   - 双击 "Copy Files" 文字
   - 改名为 **"Copy MediaRemote Script"**

### 3. 添加Copy Files Phase (Framework)

#### 3.1 创建另一个Copy Files Phase

1. 再次点击左上角的 **"+"** 按钮
2. 选择 **"New Copy Files Phase"**

#### 3.2 配置Copy Files Phase (Framework)

1. 展开新的 "Copy Files"
2. 配置选项:
   - **Destination**: 选择 **"Frameworks"**
   - **Subpath**: 留空
   - **Copy only when installing**: 取消勾选
   - **Code Sign On Copy**: ✅ **勾选**

3. 添加Framework:
   - 点击 **"+"** 按钮
   - 找到 `MediaRemoteAdapter.framework`
   - 选中它，点击 **"Add"**

4. 重命名此Phase:
   - 双击 "Copy Files"
   - 改名为 **"Copy MediaRemote Framework"**

### 4. 调整Phase顺序 (可选)

1. 在Build Phases中，你可以拖动这些phases重新排序
2. 推荐顺序:
   ```
   Dependencies
   Sources
   Frameworks
   Resources
   Copy MediaRemote Script      ← 你添加的
   Copy MediaRemate Framework   ← 你添加的
   ```

## 第三步: 验证配置

### 1. 检查文件是否在项目中

在Xcode左侧导航器中应该能看到:
```
share-my-status-client
├── mediaremote-adapter.pl
├── MediaRemoteAdapter.framework/
├── Models/
├── Services/
└── ...
```

### 2. 检查Build Phases

在Build Phases标签页应该能看到:
```
▾ Copy MediaRemote Script
  Destination: Resources
  mediaremote-adapter.pl

▾ Copy MediaRemote Framework
  Destination: Frameworks
  MediaRemoteAdapter.framework
```

### 3. Build并验证

1. Clean Build Folder: **⌘ + Shift + K**
2. Build: **⌘ + B**
3. 应该成功编译，没有错误

### 4. 验证文件被复制

Build成功后，检查产物:

```bash
# 找到build产物
cd ~/Library/Developer/Xcode/DerivedData

# 或直接检查
find ~/Library/Developer/Xcode/DerivedData -name "share-my-status-client.app" -type d

# 进入app bundle验证
cd path/to/share-my-status-client.app

# 检查脚本
ls -la Contents/Resources/mediaremote-adapter.pl

# 检查framework
ls -la Contents/Frameworks/MediaRemoteAdapter.framework
```

应该能看到这两个文件！

## 图文说明

### 添加Copy Files Phase的界面位置

```
Xcode窗口布局:

┌─────────────────────────────────────────────────────┐
│ 项目导航器         │  Build Phases 标签              │
│                   │                                 │
│ ▾ Project         │  ┌─ [+] 按钮在这里              │
│   ▾ Targets       │  │                             │
│     • client ←点这 │  ├─ Dependencies              │
│                   │  ├─ Sources                   │
│                   │  ├─ Frameworks                │
│                   │  ├─ Resources                 │
│                   │  ├─ ▾ Copy MediaRemote Script │
│                   │  │   Destination: Resources   │
│                   │  │   [+] ← 点击添加文件         │
│                   │  │   • mediaremote-adapter.pl │
│                   │  │                            │
│                   │  └─ ▾ Copy MediaRemote Framework│
│                   │      Destination: Frameworks  │
│                   │      • MediaRemoteAdapter.framework│
└───────────────────┴─────────────────────────────────┘
```

### Destination下拉菜单选项

```
Copy Files Destination选项:

┌─────────────────────────┐
│ ▾ Destination           │
│   • Absolute Path       │
│   • Products Directory  │
│   • Wrapper             │
│   • Executables         │
│   • Resources      ← 脚本选这个
│   • Frameworks     ← Framework选这个
│   • Shared Frameworks │
│   • Shared Support     │
│   • Plug-ins           │
│   • Java Resources     │
│   • XPC Services       │
└─────────────────────────┘
```

## 完整的Build Phases配置示例

最终你的Build Phases应该看起来像这样:

```
▸ Dependencies

▾ Sources (X items)
  • share_my_status_clientApp.swift
  • ContentView.swift
  • MenuBarView.swift
  • (其他所有.swift文件)

▾ Frameworks (1 item)
  • MediaRemoteAdapter.framework

▸ Resources (X items)
  • Assets.xcassets
  • (其他资源)

▾ Copy MediaRemote Script
  Destination: Resources
  Subpath: 
  ☐ Copy only when installing
  ☑ Code Sign On Copy
  • mediaremote-adapter.pl

▾ Copy MediaRemote Framework
  Destination: Frameworks
  Subpath:
  ☐ Copy only when installing  
  ☑ Code Sign On Copy
  • MediaRemoteAdapter.framework
```

## 常见错误

### ❌ 错误 1: 文件没有被复制

**症状**: 运行时提示找不到adapter文件

**原因**: Copy Files Phase配置错误

**解决**:
1. 检查Destination是否正确
2. 确认文件在Phase中
3. Clean后重新Build

### ❌ 错误 2: Code signing错误

**症状**: Build失败，提示签名问题

**原因**: 未勾选 "Code Sign On Copy"

**解决**:
1. 在每个Copy Files Phase中
2. 勾选 "Code Sign On Copy"
3. 重新Build

### ❌ 错误 3: Framework找不到

**症状**: 运行时提示framework不存在

**原因**: Framework没有添加到target或Destination错误

**解决**:
1. 重新添加framework，确保勾选target
2. Copy Files Phase的Destination设为Frameworks
3. 检查framework是否在 "Frameworks and Libraries" 中

## 验证成功的标志

运行这个命令验证配置成功:

```bash
# Build项目
cd /Users/bytedance/Codespace/share-my-status-plus/desktop/macos
xcodebuild -project share-my-status-client.xcodeproj \
           -scheme share-my-status-client \
           -configuration Debug \
           build

# 找到产物
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "share-my-status-client.app" -type d | head -1)

# 验证文件存在
echo "Checking script..."
ls -la "$APP_PATH/Contents/Resources/mediaremote-adapter.pl"

echo "Checking framework..."
ls -la "$APP_PATH/Contents/Frameworks/MediaRemoteAdapter.framework"

# 测试adapter
echo "Testing adapter..."
/usr/bin/perl \
  "$APP_PATH/Contents/Resources/mediaremote-adapter.pl" \
  "$APP_PATH/Contents/Frameworks/MediaRemoteAdapter.framework" \
  get
```

如果所有检查都通过，配置成功！✅

## 需要帮助？

如果仍有问题:
1. 截图你的Build Phases配置
2. 检查Console.app的错误日志
3. 运行上面的验证脚本并查看输出

---

**完成这些步骤后，你的应用就能正常检测音乐了！** 🎵

