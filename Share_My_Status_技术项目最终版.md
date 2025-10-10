## 1 项目概要
**这是什么**：**实时共享个人电脑状态**（音乐播放信息 + 系统指标 + **正在做的事**），让同事或朋友在**飞书个人签名**与**Web 页面**看到你的当前状态。

**怎么工作**：客户端采集并上报（**Secret Key** 鉴权）→ 服务端聚合与短窗存储 → **WebSocket** 实时推送 → Web 展示；飞书侧通过**官方 SDK 长链接订阅与事件监听**完成链接预览渲染。

**隐私与安全**：**不采集 deviceId 等敏感数据**；支持最小采集颗粒与授权开关；支持 **SharingKey 撤销** 与 **SecretKey 轮转**。

**一句话价值主张**：**轻量、实时、可控的个人状态共享，贴到签名即可用**。

![Share My Status 概览示意图](img_G8MKbaVrHoyAVUxIrHtcJW0FnAg.png)

说明：品牌中立的扁平插画，示意客户端采集→服务端 WebSocket 推送→飞书 SDK 长链接预览展示的整体路径。

## 2 项目目标与边界
**目标**：提供**秒级更新**的个人电脑状态、当前播放音乐信息与**正在做的事**的实时共享，展示在**飞书个人签名**与**公开 Web 页面**。

**范围**：

- **客户端平台**：macOS 12 及以上、Windows 10/11。

- **浏览器支持**：现代浏览器（Chrome、Edge、Safari、Firefox 最新两个大版本）。

- **实时性**：在正常网络条件下，Web 展示端到端**≤2 秒**刷新；飞书链接预览为**近实时**（受平台频控影响，通常**≤10 秒**）。

- **可用性目标**：WebSocket 链路可用性 99.9%，上报链路可用性 99.95%。

- **默认时区**：**Asia/Shanghai**（可配置）。

**非目标与约束**：

- 暂不支持 Linux 客户端与移动端客户端（移动端为路线图项）。

- **默认不存储历史**：除非用户**显式授权**，否则仅保留**短时间窗**（默认 5 分钟）供预览与“最近状态”展示；授权后按**统计时间窗**存储汇总数据。

- 不做音乐播放控制，不接入第三方用户帐号 OAuth。

> **关键设计目标**：
> - **最小权限**：上报仅用 Secret Key，公开访问仅用 Sharing Key，**强隔离**。
> - **低延迟与稳态**：前端通过 WebSocket 增量刷新，后端做**去抖与聚合**。
> - **可撤销**：用户可随时**重置 Sharing Key** 立即失效旧链接；通过机器人可**撤销公开授权**。

## 3 系统概览与数据流
客户端定期采集设备、媒体播放与**当前活动**信息，使用**Secret Key**通过 HTTPS 上报至服务端；服务端将最新状态写入**短窗存储**并通过**WebSocket**推送到使用**Sharing Key**订阅的浏览器；飞书的“链接预览能力”通过**官方 SDK 建立的长链接会话**订阅并监听事件，我们解析分享链接中的**Sharing Key**，返回可展示的预览内容。若用户授权统计，服务端按**时间窗口语义**汇总并提供查询接口。

**端到端流程**：

1. 客户端轮询采集：
	- **系统**：`batteryPct`、`charging`、`cpuPct`、`memoryPct`。
	- **音乐**：`title`、`artist`、`album`、`coverHash`（仅哈希）。
	- **活动**：`label`（本地规则映射得到，仅上传标签）。

2. 客户端上报：`POST /v1/state/report`，Header 携带 `X-Secret-Key` 鉴权，Body 为当前状态或批量事件（仅必要字段）。

3. 服务端处理：校验 Secret Key → 去抖与聚合 → 更新短窗存储（内存或 Redis）；若事件含 `coverHash` 或 `coverB64`：当存在 `coverB64` 时由服务端**解码**→以**解码后的字节**计算 MD5→写入 `cover_assets`（`asset` JSON 存 `b64`）并返回 `coverHash`；仅有 `coverHash` 时执行**哈希存在性查询**与去重。

4. Web 前端订阅：浏览器打开 `https://host/s/{SharingKey}`，前端建立 `WS /v1/ws?sharingKey=...`，服务器按房间推送最新状态与活动合并视图。

5. 飞书链接预览：通过**官方 SDK 长链接会话**订阅并监听**链接预览拉取事件**，解析 Sharing Key → 读取最新状态与活动摘要 → 返回预览内容用于签名展示；当状态变化且命中刷新策略时，触发**预览更新能力**进行刷新（遵循平台的幂等与频控约束）。**注意**：出于性能考虑，飞书链接预览**暂不渲染聚合统计变量**（`{topArtist}` 等），仅展示实时状态。

6. 统计查询（授权用户）：`POST /v1/stats/query` 指定时间窗与指标，返回**汇总与 TopN**。

| 滚动窗口 vs 日历窗口 | 示例（当前 2025-10-03） |
| --- | --- |
| - **滚动窗口**：近3天/近7天，区间 `[now-72h, now]` / `[now-168h, now]`，随时间滑动。<br>- **日历窗口**：当月/当年，区间 `[当地时区当月1日00:00, now]` / `[当地时区1月1日00:00, now]`。<br>- **自定义窗**：用户指定 `[start, end]` 与 `tz`，服务端按时区归一。 | - **本月**：`[2025-10-01 00:00, now]`（Asia/Shanghai）。<br>- **今年**：`[2025-01-01 00:00, now]`（Asia/Shanghai）。<br>- 统一语义避免跨时区误差，响应体回显 `fromTs/toTs/tz`。 |

### 3.1 链接定制与模板渲染
公开分享链接格式：`https://example.com/x/{SharingKey}?r=&m=`。

**变量总表（按类别分组）**：下列变量均来自后端可计算且允许对外呈现的最小字段集合，严格遵循隐私最小化原则；**仅支持本表列出的变量**，未列出的变量不可用。

#### 3.1.1 实时音乐
| 变量 | 含义 | 类型 | 来源字段或计算方式 | 示例 | 空值回退策略 | 长度与安全约束 | 
| --- | --- | --- | --- | --- | --- | --- | 
| `{artist}` | 歌手 | string | `snapshot.music.artist` | Taylor Swift | 空串或“未知” | **≤256**；**HTML/XSS 转义**；建议仅中英文、数字与常见标点 | 
| `{title}` | 歌曲名 | string | `snapshot.music.title` | Love Story | 空串或“未知” | **≤256**；**HTML/XSS 转义**；建议仅中英文、数字与常见标点 | 
| `{album}` | 专辑名 | string | `snapshot.music.album` | 1989 | 空串或“未知” | **≤256**；**HTML/XSS 转义**；建议仅中英文、数字与常见标点 | 

#### 3.1.2 实时系统
| 变量 | 含义 | 类型 | 来源字段或计算方式 | 示例 | 空值回退策略 | 长度与安全约束 | 
| --- | --- | --- | --- | --- | --- | --- | 
| `{batteryPct}` | 电量百分比（0–1） | number | `snapshot.system.batteryPct` | 0.82 | N/A 或空串 | 取值范围 **[0,1]**；用于派生显示 | 
| `{charging}` | 充电中 | boolean | `snapshot.system.charging` | true | 视为 false | 布尔值；**支持三元表达式** `{charging?'充电中':'未在冲电'}`；仅允许基本条件表达式，不支持复杂逻辑/函数调用 | 
| `{cpuPct}` | CPU 使用率（0–1） | number | `snapshot.system.cpuPct` | 0.23 | N/A 或空串 | 取值范围 **[0,1]**；用于派生显示 | 
| `{memoryPct}` | 内存使用率（0–1） | number | `snapshot.system.memoryPct` | 0.58 | N/A 或空串 | 取值范围 **[0,1]**；用于派生显示 | 

#### 3.1.3 实时活动
| 变量 | 含义 | 类型 | 来源字段或计算方式 | 示例 | 空值回退策略 | 长度与安全约束 | 
| --- | --- | --- | --- | --- | --- | --- | 
| `{activityLabel}` | 正在做的事标签 | string | `snapshot.activity.label` | 在工作 | 空串或“未知” | **≤64**；**HTML/XSS 转义**；不含应用名/窗口原文 | 

#### 3.1.4 派生显示
| 变量 | 含义 | 类型 | 来源字段或计算方式 | 示例 | 空值回退策略 | 长度与安全约束 | 
| --- | --- | --- | --- | --- | --- | --- | 
| `{batteryPctRounded}` | 电量百分比（整数） | number | `round(batteryPct*100)` | 82 | 显示 `N/A` | **0–100**；**四舍五入**到整数（half up） | 
| `{cpuPctRounded}` | CPU 使用率（整数） | number | `round(cpuPct*100)` | 23 | 显示 `N/A` | **0–100**；**四舍五入**到整数（half up） | 
| `{memoryPctRounded}` | 内存使用率（整数） | number | `round(memoryPct*100)` | 58 | 显示 `N/A` | **0–100**；**四舍五入**到整数（half up） | 

#### 3.1.5 时间环境
| 变量 | 含义 | 类型 | 来源字段或计算方式 | 示例 | 空值回退策略 | 长度与安全约束 | 
| --- | --- | --- | --- | --- | --- | --- | 
| `{nowISO}` | 当前时间（ISO 8601） | string | `now()` 按 `tz` 输出 RFC3339 | 2025-10-03T14:22:33+08:00 | 空串 | **≤64**；**Asia/Shanghai** 默认，可配置 | 
| `{nowLocal}` | 当前时间（本地时区） | string | `now()` 本地格式 | 2025-10-03 14:22:33 | 空串 | **≤32**；**Asia/Shanghai** 默认，可配置 | 
| `{dateYMD}` | 日期字符串 | string | `formatDate(now, 'YYYY-MM-DD')` | 2025-10-03 | 空串 | **≤16**；数字与连字符 | 

#### 3.1.6 聚合统计
> **注意事项**：
> - 以下变量需用户**显式授权**历史存储与汇总；来源为统计表。
> - **链接预览暂不支持聚合统计变量**：出于性能考虑，飞书签名链接预览**不渲染**聚合统计变量（`{topArtist}` 等）；这些变量**仅在 Web 公开页与客户端 UI 预览**中可用。

| 变量 | 含义 | 类型 | 来源字段或计算方式 | 示例 | 空值回退策略 | 长度与安全约束 | 
| --- | --- | --- | --- | --- | --- | --- | 
| `{topArtist}` | 窗口内播放最多的歌手 | string | `stats.topArtists[0].name` | Coldplay | 空串或"未知" | **≤256**；**HTML/XSS 转义** | 
| `{topTitle}` | 窗口内播放最多的歌曲名 | string | `stats.topTracks[0].track` | Yellow | 空串或"未知" | **≤256**；**HTML/XSS 转义** | 
| `{uniqueTracks}` | 唯一歌曲数 | number | `stats.uniqueTracks` | 58 | 显示 `0` | 非负整数；**≤10^9** | 
| `{playCountWindow}` | 统计窗口描述 | string | `window.type` 映射 | 近7天 | 空串 | **≤32**；受 `tz` 影响，默认 **Asia/Shanghai** | 

**模板使用规则**：

- `m`（mark）作为**轻量文本模板**，支持**本表 3.1.1-3.1.6 列出的所有变量**与**基本条件表达式**。**默认模板**为"`{artist}的{title}`"。当某字段缺失时，自动删除该占位符；布尔变量缺失时**按默认视为 false**处理。

- **支持的变量类别**：
  - **实时音乐**：`{artist}` `{title}` `{album}`
  - **实时系统**：`{batteryPct}` `{charging}` `{cpuPct}` `{memoryPct}`
  - **实时活动**：`{activityLabel}`
  - **派生显示**：`{batteryPctRounded}` `{cpuPctRounded}` `{memoryPctRounded}`
  - **时间环境**：`{nowISO}` `{nowLocal}` `{dateYMD}`
  - **聚合统计**（需授权，**仅 Web 页可用**）：`{topArtist}` `{topTitle}` `{uniqueTracks}` `{playCountWindow}`

- **条件表达式支持**：布尔变量（如 `{charging}`）支持三元表达式 `{charging?'充电中':'未在冲电'}`，仅允许**基本条件表达式**，不支持复杂逻辑、函数调用或嵌套表达式。

- **性能限制**：**飞书签名链接预览暂不支持聚合统计变量**（`{topArtist}` 等），这些变量仅在 Web 公开页渲染。

- **模板示例**：
```
{artist}的{title} — {charging?'充电中':'未在冲电'}
{title}（{album}）{charging?'⚡':''}
{activityLabel} | 🎵{artist}-{title} | 🔋{batteryPctRounded}%
正在听 {title} · {dateYMD}
{topArtist} 最多播放 · 本月已听{uniqueTracks}首
```

**r 参数与安全校验**：

- `r`（redirect）必须以 `http://` 或 `https://` 开头；执行**协议校验**、**域名白名单校验**与**XSS/HTML 转义**；空值表示不配置跳转。

> **安全与格式化说明**：
> - **长度上限**：所有文本变量建议**≤256**；过长将截断并转义。
> - **字符集建议**：中英文、数字与常见标点；可在模板中直接使用 Emoji 常量；统一做 **HTML/XSS 转义**。
> - **数字取值与舍入规则**：系统原始百分比为 **[0,1]** 浮点；派生显示按 **四舍五入到整数**（half up），范围 **0–100**。
> - **时区**：默认 **Asia/Shanghai**；`nowISO`/`nowLocal`/`dateYMD` 受 `tz` 配置影响，后端与前端统一。

## 4 密钥与安全模型
**角色与边界**：

- **Secret Key**：客户端上报鉴权，仅服务端与客户端持有；不可用于公开访问。

- **Sharing Key**：公开展示密钥，用于 Web 页面与 WS 房间分组，以及飞书签名链接解析；可撤销与重置。

**生成/轮换与撤销**：

- 生成：服务端按随机源生成，长度≥32；Secret/Sharing 分离存储。

- 轮换：支持**Secret Key 轮转**，客户端需重新配置；**Sharing Key 重置**后旧链接立即失效。

- 撤销：机器人或 UI 触发撤销 Sharing Key，断开相关房间连接并拒绝新连接。

**安全与传输**：

- **HTTPS** 强制；上报接口校验 `X-Secret-Key`；公开页仅以 Sharing Key 读取最新状态快照。

- **速率限制**：上报每 Secret Key **30 req/min**；订阅每 Sharing Key **200 连接**上限；IP 级 **10 conn/min**。

**用户标识说明**：**使用 open_id 作为唯一用户标识（飞书 OpenID），用于 SDK 会话与事件关联**。

**隐私控制**：

- 粒度化开关：音乐/系统/活动均可独立开启或关闭。

- **不采集 deviceId、appName、player、foreground、macOS 等字段**；日志与审计仅记录**事件 id、时间戳、SharingKey 的哈希或脱敏标识**。

## 5 听歌统计与授权
**时间窗口语义**：

- **近3天/近7天（滚动）**：区间为 `[now-72h, now]`、`[now-168h, now]`。

- **本月/今年（日历）**：区间为 `[tz 当月1日 00:00, now]`、`[tz 当年1月1日 00:00, now]`，`tz`默认 **Asia/Shanghai** 可配置。

- **自定义时间窗**：区间由客户端或前端指定，服务端**校验并归一**到目标 `tz`，响应回显窗口边界。

**指标与扩展**：

- **基础指标**：歌手、歌曲名。

- **扩展指标**：播放次数（plays）、唯一歌曲数（uniqueTracks）、**TopN**（topArtists、topTracks，支持 `n` 参数）。

**授权模型**：

- 客户端提供**一次性授权弹窗**与开关；未授权则**不存储历史**（仅用于实时展示）。

- 服务端保存**授权时间戳与范围**（音乐历史/统计）；授权撤销后，立即停止新增，已有数据按**保留期**与**删除策略**执行。

**数据保留与删除策略**：

- **保留期**：可配置（如 30/90 天）；到期后按策略清理。

- **删除策略**：支持**软删**（逻辑标记）与**硬删**（物理删除）。软删用于审计与可恢复窗口；硬删用于隐私诉求与合规。

> **显式授权是前提**：任何听歌历史或统计汇总的服务端持久化，均以**用户授权**为前提。未授权时，**不上报即不采集**——客户端直接跳过音乐历史采样。

**统计接口**：

```http
POST /v1/stats/query
X-Secret-Key: <secret>
Content-Type: application/json

{
  "window": "month_to_date",  // rolling_3d | rolling_7d | month_to_date | year_to_date | custom
  "tz": "Asia/Shanghai",
  "custom": { "fromTs": 1730390400000, "toTs": 1730639999000 },
  "metrics": ["plays", "unique_tracks", "top_artists", "top_tracks"],
  "topN": 10
}
```

```json
{
  "window": {
    "type": "month_to_date",
    "tz": "Asia/Shanghai",
    "fromTs": 1751280000000,
    "toTs": 1751568000000
  },
  "summary": {
    "plays": 132,
    "uniqueTracks": 58
  },
  "topArtists": [
    { "name": "Coldplay", "plays": 21 },
    { "name": "Adele", "plays": 16 }
  ],
  "topTracks": [
    { "track": "Yellow", "artist": "Coldplay", "plays": 8 },
    { "track": "Hello", "artist": "Adele", "plays": 6 }
  ],
  "warnings": []
}
```

## 6 正在做的事：客户端映射与合并策略
**规则映射**：

- 可配置**正则/窗口标题匹配**，在客户端本地将当前前台上下文**映射为标签**（例如“在工作”“在写代码”）。

- 示例：`{"pattern": "Feishu", "label": "在工作"}`，`{"pattern": "VSCode|Idea", "label": "在写代码"}`。

**与音乐状态并存**：

- **合并展示**为首选：同时显示“正在做的事”与音乐卡片。

- **优先级策略**：默认以“正在做的事”为主、音乐为次；当音乐暂停时，活动优先提升。

**上报边界**：

- **仅上报 label**；不上传应用名、窗口标题、是否前台等原始细节。所有匹配在本地完成，**不涉及敏感内容**。

> **活动采集边界**：不采集文档内容、剪贴板、键盘输入等敏感信息；不上传 `appName`、`foreground` 等原始字段，仅上传**映射后的标签**。

## 7 客户端 UI 与白名单
**UI 行为**：

- **macOS**：常驻**状态栏图标**（NSStatusItem），最小化后**不出现在 Dock**；点击图标弹出菜单与设置面板。

- **Windows**：常驻**系统托盘图标**（通知区域），右键快捷菜单进入设置与操作。

**配置项**：

- 上报 **Endpoint** 与 **Secret Key**。

- **软件白名单**（如仅处理 QQ 音乐等），用于限定本地采集来源；**不影响上报字段**（上报仅含必要字段）。

- 隐私与授权开关（音乐统计授权、公开页开关）。

- 统计时间窗选择（近3天、近7天、本月、今年、自定义）。

**运行特性**：

- **开机自启**：macOS LaunchAgent / Windows 计划任务或服务。

- 前后台切换处理：仅当前台或事件触发时提高采样频率。

- **低资源占用**：CPU 目标 < 1%，常态内存 < 80MB。

- 失败重试与本地缓冲：环形缓冲最多 50 条，队列满时丢弃**旧事件**保留最新。

### 7.1 链接定制 UI
用户在客户端内置的"链接定制"界面中，粘贴基础链接 `https://example.com/x/{SharingKey}?r=&m=`，系统自动解析并可视化拼接。

#### 7.1.1 自动解析与参数校验
- **提取 `SharingKey`**：从路径段 `x/{SharingKey}` 解析。

- **`r` 参数（redirect）**：
  - 必须以 `http://` 或 `https://` 开头。
  - 执行**协议校验**、**域名白名单校验**、**HTML/XSS 转义**。
  - 非法时给出红色提示并禁用"生成链接"；空值表示不配置跳转。

- **`m` 参数（mark 模板）**：
  - 支持**本文档 3.1.1-3.1.6 节列出的所有变量**（详见下方变量清单）。
  - 默认模板为"`{artist}的{title}`"。
  - 支持布尔变量的三元表达式（如 `{charging?'充电中':'未在冲电'}`），当布尔变量缺失时视为 `false`。
  - **模板规则限制**：仅允许使用文档定义的变量与基本条件表达式；不支持复杂逻辑、函数调用或嵌套表达式。

#### 7.1.2 可用变量清单（参照 3.1 节）
客户端 UI 应提供**变量选择器**或**插入按钮**，便于用户可视化构建模板：

| 变量类别 | 变量名 | 说明 | 示例值 |
| --- | --- | --- | --- |
| **实时音乐** | `{artist}` | 歌手 | Taylor Swift |
|  | `{title}` | 歌曲名 | Love Story |
|  | `{album}` | 专辑名 | 1989 |
| **实时系统** | `{batteryPct}` | 电量百分比（0–1） | 0.82 |
|  | `{charging}` | 充电中（布尔） | true |
|  | `{cpuPct}` | CPU 使用率（0–1） | 0.23 |
|  | `{memoryPct}` | 内存使用率（0–1） | 0.58 |
| **实时活动** | `{activityLabel}` | 正在做的事标签 | 在工作 |
| **派生显示** | `{batteryPctRounded}` | 电量百分比（整数 0–100） | 82 |
|  | `{cpuPctRounded}` | CPU 使用率（整数 0–100） | 23 |
|  | `{memoryPctRounded}` | 内存使用率（整数 0–100） | 58 |
| **时间环境** | `{nowISO}` | 当前时间（ISO 8601） | 2025-10-03T14:22:33+08:00 |
|  | `{nowLocal}` | 当前时间（本地格式） | 2025-10-03 14:22:33 |
|  | `{dateYMD}` | 日期字符串（YYYY-MM-DD） | 2025-10-03 |
| **聚合统计**（需授权，**仅 Web 页**） | `{topArtist}` | 窗口内播放最多的歌手 | Coldplay |
|  | `{topTitle}` | 窗口内播放最多的歌曲名 | Yellow |
|  | `{uniqueTracks}` | 唯一歌曲数 | 58 |
|  | `{playCountWindow}` | 统计窗口描述 | 近7天 |

> **性能限制**：聚合统计变量（`{topArtist}` `{topTitle}` `{uniqueTracks}` `{playCountWindow}`）出于性能考虑，**暂不支持在飞书签名链接预览中渲染**，仅在 Web 公开页和客户端 UI 预览中可用。

#### 7.1.3 可视化拼接与实时预览
- **所见即所得编辑器**：提供变量插入按钮或下拉选择器，用户点击即可插入变量占位符。

- **实时预览面板**：以当前状态快照渲染模板文本，实时显示最终效果。
  - 当某字段缺失时，自动删除该占位符或显示回退值（如"未知"）。
  - 布尔变量（如 `{charging}`）按三元表达式规则渲染。
  - 聚合统计变量在未授权时显示"需授权"提示；**即使已授权，也应提示"仅在 Web 页显示，飞书链接预览不支持"**。

- **校验与提示**：
  - **长度建议 ≤256**；超限时显示截断提示。
  - 统一做 **HTML/XSS 转义**。
  - **字符集建议**：中英文、数字与常见标点；可直接使用 Emoji 常量。

- **一键复制**：点击"复制最终链接"将**规范化后的 URL**（含转义后的参数）放入剪贴板。

#### 7.1.4 模板示例（供 UI 参考）
```
{artist}的{title} — {charging?'充电中':'未在冲电'}
{title}（{album}）{charging?'⚡':''}
{activityLabel} | 🎵{artist}-{title} | 🔋{batteryPctRounded}%
正在听 {title} · {dateYMD}
{topArtist} 最多播放 · 本月已听{uniqueTracks}首
```

#### 7.1.5 与本地设置联动
- **白名单联动**：变量渲染仅来自被允许的采集源（如仅 QQ 音乐）；未允许的源将显示"未采集"或置空。

- **隐私开关联动**：当用户关闭某类采集（如活动、系统指标），对应变量自动置空或不渲染；UI 应在变量选择器中**灰显或标注**已关闭的采集项。

- **授权状态联动**：聚合统计变量（`{topArtist}` 等）在未授权时，UI 应**提示用户开启授权**并链接到授权设置；已授权时正常渲染。

- **性能限制提示**：当用户选择或插入聚合统计变量时，UI 应**明确提示**："聚合统计变量仅在 Web 公开页显示，飞书签名链接预览暂不支持（性能考虑）"。建议在变量选择器中对聚合统计类别添加图标或标签（如 "🌐 仅 Web"）。

- **错误提示与兜底**：
  - 解析失败或预览不可用时，降级为默认模板"`{artist}的{title}`"。
  - 当无音乐播放时显示"未在播放"；无活动时显示"无活动"。
  - 模板语法错误时，给出明确错误提示（如"不支持的变量"或"表达式格式错误"）。

> **客户端链接定制安全与兜底**：
> - 所有用户输入（`r`/`m` 参数）统一做 **协议校验 + 白名单校验 + HTML/XSS 转义**。
> - 布尔变量的三元表达式仅允许**简单条件**；不支持函数调用与嵌套逻辑。
> - 当链接不可用或模板变量缺失时，**自动回退**到默认模板并提示用户。
> - 变量值的**长度与安全约束**详见本文档 3.1 节变量总表。

## 8 通用上报协议（Go 强类型与 JSON）
**事件类型与版本**：使用 `version:"1"`。支持 `system`、`music`、`activity` 三类载荷，允许**批量上报**与**幂等**。

```go
// 最小必要字段的强类型定义（不含被禁字段）
type Music struct {
    Title     string `json:"title"`
    Artist    string `json:"artist"`
    Album     string `json:"album"`
    CoverHash string `json:"coverHash,omitempty"`
}

type System struct {
    BatteryPct float64 `json:"batteryPct,omitempty"` // 0-1
    Charging   bool    `json:"charging,omitempty"`
    CpuPct     float64 `json:"cpuPct,omitempty"`     // 0-1
    MemoryPct  float64 `json:"memoryPct,omitempty"`  // 0-1
}

type Activity struct {
    Label string `json:"label"` // 如：在工作、在写代码
}

type ReportEvent struct {
    Version         string    `json:"version"` // "1"
    Ts              int64     `json:"ts"`      // 毫秒
    System          *System   `json:"system,omitempty"`
    Music           *Music    `json:"music,omitempty"`
    Activity        *Activity `json:"activity,omitempty"`
    IdempotencyKey  string    `json:"idempotencyKey,omitempty"` // 客户端生成 UUID
}

type BatchReportRequest struct { Events []ReportEvent `json:"events"` }

type BatchReportResponse struct {
    Accepted int      `json:"accepted"`
    Deduped  int      `json:"deduped"`
    Warnings []string `json:"warnings,omitempty"`
}
```

**JSON 请求示例**：

```http
POST /v1/state/report
X-Secret-Key: <secret>
Content-Type: application/json

{
  "events": [
    {
      "version": "1",
      "ts": 1751568123456,
      "system": {"batteryPct": 0.82, "charging": true, "cpuPct": 0.23, "memoryPct": 0.58},
      "music": {"title": "Yellow", "artist": "Coldplay", "album": "Parachutes", "coverHash": "f5d1278e..."},
      "activity": {"label": "在工作"},
      "idempotencyKey": "d1c1f5e2-9f84-4c67-a8f0-1b9f5c7d6e21"
    }
  ]
}
```

**错误码与幂等语义**：

- `OK` 200：正常。

- `INVALID_KEY` 401：Secret Key 无效或过期。

- `RATE_LIMIT` 429：触发速率限制或房间上限。

- `UNAUTHORIZED_STAT_STORAGE` 403：未授权存储统计。

- `DUPLICATE_HASH` 409：封面哈希已存在（返回指针）。

- `BAD_REQUEST` 400：参数缺失或不合法。

- 幂等：同一 `idempotencyKey` 的事件**只处理一次**；批量内重复自动去重并统计到 `deduped`。

**批量上报与队列缓冲**：

- 客户端可将 1–10 条事件批量上报；服务端写入队列（如本地 Channel/Redis Stream）做**去抖聚合**与**异步推送**。

## 9 音乐封面性能与流量优化（去重）
**客户端优化**：

- 封面按**MD5 内容哈希**计算并缓存；上传前先调用**存在性查询**，命中则只上传哈希与元数据。

- 本地 LRU 缓存小尺寸缩略图，优先复用；失败回退到占位图。

**服务端去重与派生**：

- 存储以**哈希为主键**，维护**引用计数**与**最近使用时间**；清理策略按 LRU 或 TTL。

- 按哈希派生多规格（128px/256px），配合**CDN 缓存**与长缓存头；前端优先加载**缩略图**。

**接口约定**：

```http
// 查询封面是否已存在（返回指针或404）
GET /v1/cover/exists?md5=f5d1278e...

// 上传封面（application/json：{"b64": "<base64>" }），服务端解码→计算 MD5→入库 cover_assets（asset JSON）
POST /v1/cover/upload

// 按规格获取封面
GET /v1/cover/{hash}?size=128
```

**上报与展示**：上报事件仅传 `coverHash` 与必要元数据；前端收到指针后按规格拉取，未命中时显示占位图。

> **端到端优化要点**：
> - **先查后传**：客户端命中哈希后避免重复上传。
> - **优先传哈希**：事件体不携带图片二进制；当缺少已有封面记录时**可选上传 coverB64（base64）**，由服务端解码后计算 MD5 入库。
> - **多规格派生+CDN**：后端一次存储，多处复用，前端快速首屏。

## 10 采集最小颗粒度与隐私
**最小颗粒度配置**：

- 客户端对每项采集（系统、音乐、活动）提供独立开关；用户未选择的项目**避免采集**（**不上报即不采集**）。

- UI 对每项采集**用途提示**与隐私说明；默认最小化收集。

**透明化**：设置面板展示当前生效配置、授权状态与生效的统计时间窗；可一键关闭公开页与撤销授权。

## 11 飞书机器人交互
**命令格式**：

- `/status revoke`：撤销当前 **SharingKey**（公开页立即失效，WS 房间强制关闭）。

- `/status rotate`：轮转 **SecretKey**（客户端需重新配置）。

- `/status publish on|off`：打开/关闭 **Web 公开授权**。

**交互流程**：

1. 用户在机器人会话中输入命令。

2. 机器人调用后端接口，进行**用户绑定校验**与**签名验证**（如 `X-Signature` + 时间戳）。

3. 通过权限与频控（如 10/min）后执行操作；返回成功提示与后续动作（如“重新配置客户端 SecretKey”）。

4. 记录**审计日志**（操作人、时间、旧值/新值、结果），并发送通知。

**安全校验与权限**：

- 机器人需绑定用户帐号与我们的账户系统；命令仅作用于**本人资源**。

- 采用**签名验证**与**重放防护**（时间戳窗口与一次性 nonce）。

- 失败提示清晰可执行（如“当前未开启公开授权”、“请先绑定账户”）。

## 12 服务端设计
**接口设计**：

- 上报：`POST /v1/state/report`（支持批量）。

- 查询最近：`GET /v1/state/query?sharingKey=...`。

- 统计：`POST /v1/stats/query`（需授权）。

- WebSocket：`GET /v1/ws?sharingKey=...`。

- 飞书事件处理：在**官方 SDK 长链接会话**内接收**链接预览拉取事件**，内部 handler 解析请求并执行预览渲染与必要的**预览更新能力**，遵循幂等与频控。**注意**：出于性能考虑，飞书链接预览**暂不支持聚合统计变量渲染**，仅返回实时状态（音乐、系统、活动）。

- 封面：`GET /v1/cover/exists`、`POST /v1/cover/upload`、`GET /v1/cover/{id}`。

**WebSocket 频道模型**：

- 按 **Sharing Key** 建立房间（Room）；订阅连入后立即下发**最近状态快照**，随后**增量广播**。

- 心跳：服务器每 25 秒发送 `ping`，若 10 秒未收到 `pong`，断开连接。

- 广播/单播：支持按房间广播与对单一连接单播（如恢复快照与差分）。

**状态聚合与去抖**：

- 按用户维度**去抖**（默认 250ms），避免高频重复上报导致推送风暴。

- **活动与音乐**分通道聚合，前端按组件更新；当房间人数多于阈值时切换**字段差分广播**。

**数据保留与时间窗**：

- **短窗**：最近 **5 分钟**状态快照用于实时展示（内存或 Redis Sorted Set，带 TTL）。

- **统计窗**（授权）：按配置存储**滚动/日历/自定义**窗口的统计桶（如 HLL/Count-Min/TopK 结构或聚合表），支持每日/月度增量刷新。

**扩展性与缓存**：

- 无状态服务，水平扩展；WebSocket 房间通过**Redis Pub/Sub** 或**一致性哈希**分布。

- 热路径使用本地 LRU 与短缓存（飞书预览 30–60 秒）。

**速率限制与防刷**：

- 上报：每 Secret Key 默认 **30 req/min**，突发 10。

- 订阅：每 Sharing Key 默认 **200 连接**上限；IP 级 **10 conn/min**。

- 封面接口：哈希查询 **500 QPS/实例** 目标，命中率目标 **≥95%**。

## 13 Web 前端
**状态展示组件**：卡片式布局，分为**音乐卡**、**系统卡**与**活动卡**；活动卡优先展示映射后的“正在做的事”。

- 首屏渲染：加载最近快照；随后以事件流**增量更新**。

- 合并策略：当音乐与活动同时存在，卡片并列显示；当音乐暂停时，活动卡提升主位。

**连接管理**：

- 建立 `WS /v1/ws?sharingKey=...`，实现**心跳、超时、指数退避重连**。

- 可视化连接状态（已连接、重连中、离线）。

**访问控制与隐私提示**：

- 公开页默认公开用户开启的字段；显著展示**隐私提示**与“关闭公开”的入口链接。

**移动端适配**：

- 响应式卡片布局，优先纵向信息；保留心跳与重连逻辑。

## 14 数据模型与示例
### 14.1 Golang 强类型与统一响应（代码直出）
```go
package api

import "time"

// 统一响应封装：所有 HTTP 响应均采用 {"code":0,"message":"success","data":<ANY>}
type APIResponse[T any] struct {
    Code    int    `json:"code"`    // 0=success；非0为错误码
    Message string `json:"message"` // "success" 或错误描述
    Data    T      `json:"data"`    // 载荷
}

// ===== 状态快照（最小必要字段；与 MySQL 8.0 Schema/GORM 模型一致） =====
type SystemSnapshot struct {
    BatteryPct float64 `json:"batteryPct,omitempty"` // 0..1；缺失时不返回（omitempty）
    Charging   bool    `json:"charging,omitempty"`   // true/false；缺失按 false 处理
    CpuPct     float64 `json:"cpuPct,omitempty"`     // 0..1
    MemoryPct  float64 `json:"memoryPct,omitempty"`  // 0..1
}

type MusicSnapshot struct {
    Title     string `json:"title"`               // 曲目名
    Artist    string `json:"artist"`              // 歌手
    Album     string `json:"album"`               // 专辑
    CoverHash string `json:"coverHash,omitempty"` // 封面哈希；仅用于资源去重
    CoverB64  string `json:"coverB64,omitempty"`  // 可选：缺少已有封面记录时上传 base64；服务端解码→MD5→入库 cover_assets
}

type ActivitySnapshot struct {
    Label string `json:"label,omitempty"` // 正在做的事标签；为空则不返回
}

type StateSnapshot struct {
    System   *SystemSnapshot   `json:"system,omitempty"`
    Music    *MusicSnapshot    `json:"music,omitempty"`
    Activity *ActivitySnapshot `json:"activity,omitempty"`
    Ts       int64             `json:"ts"` // 毫秒时间戳
}

// ===== 1) 状态上报请求载荷（HTTP POST /v1/state/report） =====
// 仅携带当前快照；遵循隐私最小化（不包含 deviceId/appName/macOS/player/foreground）
type ReportStateRequest struct {
    Snapshot       StateSnapshot `json:"snapshot"`              // 当前状态快照
    IdempotencyKey string        `json:"idempotencyKey,omitempty"` // 客户端 UUID；服务端幂等去重
}

type ReportStateResponse struct {
    UpdatedAt string `json:"updatedAt"` // RFC3339；服务端接收与落库时间
}
// 响应示例：APIResponse[ReportStateResponse]{Code:0,Message:"success",Data:{UpdatedAt:"2025-10-04T10:00:00+08:00"}}

// ===== 2) 状态查询与实时订阅（WebSocket） =====
type WSMessage[T any] struct {
    Type      string    `json:"type"`      // "state.update" | "stats.update" | "error" ...
    Data      T         `json:"data"`      // 实际载荷
    Timestamp time.Time `json:"timestamp"` // 服务器生成时间
}

// "state.update" → 当前状态快照（最小字段集）
type StateUpdatePayload = StateSnapshot

// "stats.update" → 窗口统计结果（最小必要字段）
type StatsPayload struct {
    TopArtist       string `json:"topArtist,omitempty"`    // 窗口内播放最多的歌手；无数据则省略
    TopTitle        string `json:"topTitle,omitempty"`     // 窗口内播放最多的歌曲名；无数据则省略
    UniqueTracks    int    `json:"uniqueTracks,omitempty"` // 唯一歌曲数；缺失时返回 0 或省略
    PlayCountWindow string `json:"playCountWindow"`        // 统计窗口描述，如 "近7天"、"本月"
}

// 取值范围与回退策略：
// - 百分比：battery/cpu/memory 为 [0..1] 浮点；展示层如需整数，按 round(x*100)。
// - charging：布尔；缺失视为 false。模板支持三元表达式 {charging?'充电中':'未在冲电'}。
// - 文本：缺失时按空串或“未知”回退；统一做 HTML/XSS 转义。
// - 封面：`coverB64` 仅在缺少已有封面记录时上传；服务端**解码**→以**解码后的字节**计算 MD5→入库 `cover_assets`（`asset` JSON 存 `b64`），响应返回 `coverHash`；**不提供 `content_type/size_bytes`**。
// - 统计：缺数据时 Top* 字段省略；uniqueTracks 缺失时返回 0 或省略。

// ===== 3) 统计查询请求（HTTP GET/POST /v1/stats/query） =====
// 支持滚动窗口（rolling_3d/rolling_7d）、日历窗口（month_to_date/year_to_date）与自定义窗
type StatsQueryRequest struct {
    WindowType string `json:"windowType"`          // rolling_3d | rolling_7d | month_to_date | year_to_date | custom
    StartTime  int64  `json:"startTime,omitempty"` // 毫秒；custom 时必填
    EndTime    int64  `json:"endTime,omitempty"`   // 毫秒；custom 时必填
    Tz         string `json:"tz,omitempty"`        // 时区，默认 "Asia/Shanghai"
    TopN       int    `json:"topN,omitempty"`      // 可选 TopN，默认 5
}
// 响应为 APIResponse[StatsPayload]
```

> **隐私与一致性**：以上 Golang Struct 均遵循**隐私最小化**（不含 deviceId、appName、macOS、player、foreground），与文档中的 **MySQL 8.0 Schema/GORM 模型**字段一致。展示层需对外文本统一做 **HTML/XSS 转义**，布尔充电支持三元表达式模板。

### 14.2 数据库 Schema（MySQL 8.0 + JSON）
**总体原则**：以 **JSON** 存储状态载荷与统计结果，结合**生成列（Generated Columns，STORED）**与**二级索引**提升查询与聚合效率；**ENGINE=InnoDB**，**COLLATE=utf8mb4_0900_ai_ci**；不落敏感标识（如 deviceId），仅保留必要字段。

```sql
-- 用户与密钥管理
CREATE TABLE users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '内部主键',
  open_id VARCHAR(64) NOT NULL COMMENT '飞书 OpenID，唯一用户标识',
  secret_key VARBINARY(64) NOT NULL COMMENT '客户端上报密钥（服务端以哈希存储）',
  sharing_key VARCHAR(64) NOT NULL COMMENT '公开展示密钥，拼接分享链接',
  status TINYINT NOT NULL DEFAULT 1 COMMENT '用户状态：0=禁用，1=启用',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  UNIQUE KEY uk_open_id (open_id),
  UNIQUE KEY uk_secret_key (secret_key),
  UNIQUE KEY uk_sharing_key (sharing_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='用户与密钥管理';

-- 用户策略与隐私设置（JSON）
CREATE TABLE user_settings (
  open_id VARCHAR(64) NOT NULL PRIMARY KEY COMMENT '飞书 OpenID（FK）',
  settings JSON NOT NULL COMMENT '用户隐私与功能开关（JSON）',
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  authorized_music_stats TINYINT(1)
    GENERATED ALWAYS AS (
      CAST(JSON_UNQUOTE(JSON_EXTRACT(settings, '$.authorizedMusicStats')) AS UNSIGNED)
    ) STORED COMMENT '是否授权存储音乐统计',
  public_enabled TINYINT(1)
    GENERATED ALWAYS AS (
      CAST(JSON_UNQUOTE(JSON_EXTRACT(settings, '$.publicEnabled')) AS UNSIGNED)
    ) STORED COMMENT '是否开启公开页',
  default_tz VARCHAR(32)
    GENERATED ALWAYS AS (
      JSON_UNQUOTE(JSON_EXTRACT(settings, '$.defaultTz'))
    ) STORED COMMENT '默认时区',
  KEY ix_user_settings_authorized (authorized_music_stats),
  KEY ix_user_settings_public (public_enabled),
  KEY ix_user_settings_tz (default_tz),
  CONSTRAINT fk_settings_user FOREIGN KEY (open_id) REFERENCES users(open_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='用户隐私设置（JSON）';

-- 当前状态快照（JSON）
CREATE TABLE current_state (
  open_id VARCHAR(64) NOT NULL PRIMARY KEY COMMENT '飞书 OpenID（FK）',
  snapshot JSON NOT NULL COMMENT '当前状态快照（System/Music/Activity）',
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  music_title VARCHAR(256)
    GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(snapshot, '$.music.title'))) STORED COMMENT '曲目名',
  music_artist VARCHAR(256)
    GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(snapshot, '$.music.artist'))) STORED COMMENT '歌手',
  music_album VARCHAR(256)
    GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(snapshot, '$.music.album'))) STORED COMMENT '专辑',
  cover_hash CHAR(32)
    GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(snapshot, '$.music.coverHash'))) STORED COMMENT '封面哈希',
  battery_pct DECIMAL(5,2)
    GENERATED ALWAYS AS (
      CAST(JSON_UNQUOTE(JSON_EXTRACT(snapshot, '$.system.batteryPct')) AS DECIMAL(5,2))
    ) STORED COMMENT '电量百分比',
  charging TINYINT(1)
    GENERATED ALWAYS AS (
      CAST(JSON_UNQUOTE(JSON_EXTRACT(snapshot, '$.system.charging')) AS UNSIGNED)
    ) STORED COMMENT '是否充电',
  cpu_pct DECIMAL(5,2)
    GENERATED ALWAYS AS (
      CAST(JSON_UNQUOTE(JSON_EXTRACT(snapshot, '$.system.cpuPct')) AS DECIMAL(5,2))
    ) STORED COMMENT 'CPU 使用率',
  memory_pct DECIMAL(5,2)
    GENERATED ALWAYS AS (
      CAST(JSON_UNQUOTE(JSON_EXTRACT(snapshot, '$.system.memoryPct')) AS DECIMAL(5,2))
    ) STORED COMMENT '内存使用率',
  activity_label VARCHAR(64)
    GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(snapshot, '$.activity.label'))) STORED COMMENT '活动标签',
  KEY ix_state_updated (updated_at),
  KEY ix_state_cover (cover_hash),
  KEY ix_state_artist (music_artist),
  KEY ix_state_title (music_title),
  KEY ix_state_activity (activity_label),
  KEY ix_state_battery (battery_pct),
  KEY ix_state_cpu (cpu_pct),
  CONSTRAINT fk_current_user FOREIGN KEY (open_id) REFERENCES users(open_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='当前状态快照（JSON）';

-- 历史状态流（JSON + 记录时间）
CREATE TABLE state_history (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '历史记录主键',
  open_id VARCHAR(64) NOT NULL COMMENT '飞书 OpenID（FK）',
  recorded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '记录时间',
  snapshot JSON NOT NULL COMMENT '状态快照（JSON）',
  music_title VARCHAR(256)
    GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(snapshot, '$.music.title'))) STORED COMMENT '曲目名',
  music_artist VARCHAR(256)
    GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(snapshot, '$.music.artist'))) STORED COMMENT '歌手',
  music_album VARCHAR(256)
    GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(snapshot, '$.music.album'))) STORED COMMENT '专辑',
  cover_hash CHAR(32)
    GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(snapshot, '$.music.coverHash'))) STORED COMMENT '封面哈希',
  activity_label VARCHAR(64)
    GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(snapshot, '$.activity.label'))) STORED COMMENT '活动标签',
  KEY ix_hist_user_time (open_id, recorded_at),
  KEY ix_hist_cover (cover_hash),
  KEY ix_hist_artist_title (music_artist, music_title),
  KEY ix_hist_activity (activity_label),
  CONSTRAINT fk_history_user FOREIGN KEY (open_id) REFERENCES users(open_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='历史状态流水（JSON）';

-- 封面资源去重（MD5 主键）
CREATE TABLE cover_assets (
  cover_hash CHAR(32) PRIMARY KEY COMMENT 'MD5 of decoded image bytes，用于封面去重',
  asset JSON NOT NULL COMMENT '封面内容，字段 b64 为 base64 字符串',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='封面资源（仅存 base64 JSON，不再提供 content_type/size_bytes；扩展字段可置于 asset JSON）';

-- 聚合统计结果（JSON；支持窗口类型与起止时间）
CREATE TABLE music_stats (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '统计主键',
  open_id VARCHAR(64) NOT NULL COMMENT '飞书 OpenID（FK）',
  window_type ENUM('rolling_3d','rolling_7d','month_to_date','year_to_date','custom') NOT NULL COMMENT '窗口类型',
  tz VARCHAR(32) NOT NULL DEFAULT 'Asia/Shanghai' COMMENT '时区',
  start_time TIMESTAMP NOT NULL COMMENT '窗口开始',
  end_time TIMESTAMP NOT NULL COMMENT '窗口结束',
  stats JSON NOT NULL COMMENT '统计载荷（JSON：plays/uniqueTracks/topArtists/topTracks）',
  plays INT GENERATED ALWAYS AS (
    CAST(JSON_UNQUOTE(JSON_EXTRACT(stats, '$.plays')) AS UNSIGNED)
  ) STORED COMMENT '播放次数',
  unique_tracks INT GENERATED ALWAYS AS (
    CAST(JSON_UNQUOTE(JSON_EXTRACT(stats, '$.uniqueTracks')) AS UNSIGNED)
  ) STORED COMMENT '唯一歌曲数',
  UNIQUE KEY uk_user_window (open_id, window_type, start_time, end_time),
  KEY ix_stats_plays (plays),
  KEY ix_stats_unique (unique_tracks),
  CONSTRAINT fk_stats_user FOREIGN KEY (open_id) REFERENCES users(open_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='音乐统计结果（JSON）';
```

**主键与索引建议**：

- `users`：`id` 主键；`open_id`、`secret_key`、`sharing_key` 唯一索引，便于查找与撤销。

- `user_settings`：对 `authorized_music_stats`、`public_enabled` 建索引，便于筛选与审计；`default_tz` 辅助查询。

- `current_state`：`open_id` 主键；对 `updated_at`、`cover_hash`、`music_artist/title`、`activity_label`、`battery_pct`、`cpu_pct` 建索引，支撑前端查询与去重。

- `state_history`：`(open_id, recorded_at)` 复合索引；对 `music_artist/title` 与 `activity_label` 建索引用于统计与检索。

- `cover_assets`：`cover_hash` 主键；`asset` JSON **仅存 base64**；**不提供 content_type/size_bytes**；结合 CDN 缓存策略按访问路径控制缓存与清理。

- `music_stats`：`uk_user_window` 唯一约束避免重复窗口；对 `plays`、`unique_tracks` 建索引用于看板排序。

> **保留与清理策略**：
> - `current_state`：仅保留最近快照；无清理任务，按覆盖更新。
> - `state_history`：按用户与时间窗**分片/归档**；默认保留 30–90 天，批任务按 `recorded_at` 清理。
> - `cover_assets`：CDN 长缓存与本地引用计数结合；低引用或久未使用的条目按策略清理。
> - `music_stats`：保留最近窗口与月/年聚合；过期窗口可重算或清理。

### 14.3 Golang GORM 模型（使用 datatypes）
**选择原则**：

- **datatypes.JSON** 适合需要 JSON 路径查询（JSONQuery）的场景；

- **datatypes.JSONType[T]** 提供**强类型**体验（自动序列化/反序列化），更安全；如需复杂查询，**推荐使用 MySQL 8.0 的生成列 + 索引**，少用运行时 JSON 路径。

```go
package model

import (
    "time"
    "gorm.io/gorm"
    "gorm.io/datatypes"
)

// =====================================
// users（统一使用 open_id）
// =====================================
type User struct {
    ID        uint64    `gorm:"column:id;primaryKey;autoIncrement"`
    OpenID    string    `gorm:"column:open_id;type:varchar(64);uniqueIndex;not null"`
    SecretKey []byte    `gorm:"column:secret_key;type:varbinary(64);uniqueIndex;not null"`
    SharingKey string   `gorm:"column:sharing_key;type:varchar(64);uniqueIndex;not null"`
    Status    int       `gorm:"column:status;type:tinyint;not null;default:1"`
    CreatedAt time.Time `gorm:"column:created_at"`
    UpdatedAt time.Time `gorm:"column:updated_at"`
}

// =====================================
// user_settings（JSONType[T]）
// =====================================
type SettingsPayload struct {
    AuthorizedMusicStats bool   `json:"authorizedMusicStats"`
    PublicEnabled        bool   `json:"publicEnabled"`
    DefaultTz            string `json:"defaultTz"`
}

type UserSettings struct {
    OpenID    string                              `gorm:"column:open_id;type:varchar(64);primaryKey"`
    Settings  datatypes.JSONType[SettingsPayload] `gorm:"column:settings;type:json;not null"`
    UpdatedAt time.Time                           `gorm:"column:updated_at;autoUpdateTime"`
}

// =====================================
// Typed Payload：状态快照（仅必要字段）
// =====================================
type MusicPayload struct {
    Title     string `json:"title"`
    Artist    string `json:"artist"`
    Album     string `json:"album"`
    CoverHash string `json:"coverHash,omitempty"`
}

type SystemPayload struct {
    BatteryPct float64 `json:"batteryPct,omitempty"` // 0–1
    Charging   bool    `json:"charging,omitempty"`
    CpuPct     float64 `json:"cpuPct,omitempty"`     // 0–1
    MemoryPct  float64 `json:"memoryPct,omitempty"`  // 0–1
}

type ActivityPayload struct {
    Label string `json:"label"`
}

type StatusSnapshot struct {
    System   *SystemPayload   `json:"system,omitempty"`
    Music    *MusicPayload    `json:"music,omitempty"`
    Activity *ActivityPayload `json:"activity,omitempty"`
}

// =====================================
// current_state（JSONType[T]）
// =====================================
type CurrentState struct {
    OpenID    string                             `gorm:"column:open_id;type:varchar(64);primaryKey"`
    Snapshot  datatypes.JSONType[StatusSnapshot] `gorm:"column:snapshot;type:json;not null"`
    UpdatedAt time.Time                          `gorm:"column:updated_at;autoUpdateTime"`
}

// =====================================
// state_history（JSONType[T]）
// =====================================
type StateHistory struct {
    ID         uint64                            `gorm:"column:id;primaryKey;autoIncrement"`
    OpenID     string                            `gorm:"column:open_id;type:varchar(64);index:ix_hist_user_time,priority:1"`
    RecordedAt time.Time                         `gorm:"column:recorded_at;index:ix_hist_user_time,priority:2"`
    Snapshot   datatypes.JSONType[StatusSnapshot] `gorm:"column:snapshot;type:json;not null"`
}

// =====================================
// cover_assets（仅存 base64 JSON；取消 content_type 与 size_bytes）
// =====================================
type CoverAssetPayload struct {
    B64 string `json:"b64"`
}

type CoverAsset struct {
    CoverHash string                                `gorm:"column:cover_hash;type:char(32);primaryKey" json:"coverHash"`
    Asset     datatypes.JSONType[CoverAssetPayload] `gorm:"column:asset;type:json;not null" json:"asset"`
    CreatedAt time.Time                             `gorm:"column:created_at"`
    UpdatedAt time.Time                             `gorm:"column:updated_at"`
}

// =====================================
// music_stats（JSONType[T]）
// =====================================
type MusicStatsPayload struct {
    Plays        int         `json:"plays"`
    UniqueTracks int         `json:"uniqueTracks"`
    TopArtists   []TopArtist `json:"topArtists"`
    TopTracks    []TopTrack  `json:"topTracks"`
}

type TopArtist struct {
    Name  string `json:"name"`
    Plays int    `json:"plays"`
}

type TopTrack struct {
    Track  string `json:"track"`
    Artist string `json:"artist"`
    Plays  int    `json:"plays"`
}

type MusicStats struct {
    ID         uint64                         `gorm:"column:id;primaryKey;autoIncrement"`
    OpenID     string                         `gorm:"column:open_id;type:varchar(64);index:uk_user_window,unique,priority:1"`
    WindowType string                         `gorm:"column:window_type;type:enum('rolling_3d','rolling_7d','month_to_date','year_to_date','custom');index:uk_user_window,unique,priority:2"`
    Tz         string                         `gorm:"column:tz;size:32;not null"`
    StartTime  time.Time                      `gorm:"column:start_time;index:uk_user_window,unique,priority:3"`
    EndTime    time.Time                      `gorm:"column:end_time;index:uk_user_window,unique,priority:4"`
    Stats      datatypes.JSONType[MusicStatsPayload] `gorm:"column:stats;type:json;not null"`
    CreatedAt  time.Time                      `gorm:"column:created_at"`
    UpdatedAt  time.Time                      `gorm:"column:updated_at"`
}
```

> **封面资源存储策略（统一更新）**：
> - **仅存 base64**：`cover_assets.asset` 为 JSON，字段 `b64` 存 base64 字符串。
> - **不再提供 content_type 与 size_bytes**：如需扩展，未来可在 `asset` JSON 增加其他字段。
> - **哈希去重**：`cover_hash` 为**解码后的字节**的 MD5，作为主键实现去重。

**读写示例（Typed JSON）**：

```go
// 写入：自动序列化为 MySQL JSON
snap := datatypes.NewJSONType(StatusSnapshot{
    System:   &SystemPayload{BatteryPct: 0.82, Charging: true, CpuPct: 0.23, MemoryPct: 0.58},
    Music:    &MusicPayload{Title: "Yellow", Artist: "Coldplay", Album: "Parachutes", CoverHash: "f5d1278e..."},
    Activity: &ActivityPayload{Label: "在工作"},
})
_ = db.Create(&CurrentState{OpenID: "ou_abc123", Snapshot: snap}).Error

// 读取：自动反序列化为强类型
var out CurrentState
_ = db.First(&out, "open_id = ?", "ou_abc123").Error
if out.Snapshot.Data != nil && out.Snapshot.Data.Music != nil {
    println(out.Snapshot.Data.Music.Title) // Yellow
}
```

**查询与索引实践**：

- **JSON 路径查询**：如需对 JSON 内部键做查询，使用 `datatypes.JSON` + `datatypes.JSONQuery`，或直接使用**生成列**配合普通索引（推荐）。

- **示例（生成列）**：

```go
// 直接利用数据库生成列（music_artist、battery_pct）做查询与分页
var rows []CurrentState
_ = db.Model(&CurrentState{}).Where("battery_pct > ?", 0.8).Order("music_artist ASC").Find(&rows).Error
```

> **迁移与索引注意事项**：
> - **AutoMigrate 不会创建生成列与其索引**，需通过手工 SQL（本节 DDL）或 `db.Exec` 执行 `ALTER TABLE`。
> - **JSONType[T] 不支持 JSONQuery**，如需 JSON 路径查询，请改用 `datatypes.JSON` 或依赖**生成列 + 索引**。
> - **MySQL 版本 8.0+**：获得 JSON 函数、生成列与函数索引的能力；低版本不建议使用 JSON 列。

## 15 实时通信与策略
**协议选择**：Web 前端采用 **WebSocket** 双向通信；客户端上报用 **HTTPS REST** 便于离线与重试。

**心跳与重连**：

- 心跳间隔 25 秒，超时 10 秒断开；重连采用指数退避并在成功后**下发快照**补齐。

**广播策略**：

- 后端按房间内所有连接**广播**最新状态；当房间人数较多时启用**字段差分广播**以降带宽。

**分组与房间**：

- WS 广播/单播按 **SharingKey 房间分组**；用户撤销 SharingKey 后所在房间**强制关闭**并拒绝新连接。

**去抖与聚合**：

- 当活动/音乐/系统状态变化频繁时，服务端按事件类型做**去抖与合并**（250–500ms），保证端到端稳定与低抖动。

## 16 隐私、合规与用户控制
**可见性**：公开页默认公开用户开启的字段；飞书预览只展示**摘要级信息**。

**最小化收集**：仅采集展示所需字段；未选择的项目**不采集**（客观上也不占用 CPU 与网络）。

**删除与撤销**：用户可删除设备、暂停上报、重置 Sharing Key；授权撤销后立即停止采集与存储，按保留期清理已存聚合数据。

**审计日志**：记录**上报事件元数据**（时间、大小）、**事件处理次数**与**房间在线人数**、**机器人操作日志**（命令、结果）。

## 17 性能与容量规划
**目标负载**：

- 并发 WebSocket 连接：每房间 ≤200、全站 50k。

- 上报吞吐：峰值 10k req/s，稳态去抖后有效事件 3k req/s。

- 封面哈希查询：目标 **500 QPS/实例**，缓存命中率 **≥95%**。

**延迟指标**：

- 上报至前端可见：P95 ≤ 1.5 秒、P99 ≤ 3 秒。

- 飞书预览响应：P95 ≤ 500 ms（命中缓存 ≤ 100 ms）。**注意**：出于性能考虑，飞书链接预览**不查询聚合统计变量**（避免额外数据库查询与统计计算），仅返回实时状态快照。

- 封面查询与指针下发：P95 ≤ 30 ms（命中内存/CDN）。

**资源上限**：

- 单实例内存 ≤ 2 GiB；Redis 用作共享短窗与 Pub/Sub；封面存储按哈希主键 + 引用计数。

**白名单降低采集开销**：

- 启用软件白名单后，音乐事件采集与解析仅对指定播放器生效，**CPU 与 I/O 降幅显著**（粗略估计 40–60%）。

## 18 部署与配置
部署与配置

**目标**：提供可直接落地的 Docker 与 Kubernetes（Helm）部署清单，覆盖后端（Golang）、前端（React+Nginx）、MySQL 8.0、Redis，以及 Prometheus/Grafana/Alertmanager 的监控与告警。部署全程遵循隐私约束：**不收集 deviceId、appName、macOS、player、foreground**；音乐仅用 **title/artist/album**；封面仅用 **coverHash/coverB64（内部用途）**；模板变量**不暴露 coverHash**；日志对 `open_id` 等敏感标识**做哈希或脱敏**。

> **关键动作点**：
> - **不要向仓库提交 .env 与任何密钥文件**；本地用 dotenv 管理，生产用 **Kubernetes Secret** 注入。
> - **统一健康检查路径**：后端与 Nginx 均提供 `/healthz`；K8s 使用 **Readiness/Liveness probes**。
> - **监控默认开启**：后端暴露 `/metrics`；Prometheus 挂载规则文件；Grafana 预配置看板；Alertmanager 加载告警路由与接收人。

### 18.1 Docker 部署方案
#### 18.1.1 后端（Golang）Dockerfile：多阶段构建（go1.22-alpine → distroless 或 alpine 运行）
```dockerfile
# Dockerfile.api.distroless
# 构建阶段：go1.22-alpine，CGO=0，静态编译
FROM golang:1.22-alpine AS builder
RUN apk add --no-cache ca-certificates tzdata
ENV CGO_ENABLED=0 GOOS=linux GOARCH=amd64
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# 使用构建缓存加速；-trimpath/-ldflags减小体积
RUN --mount=type=cache,target=/root/.cache/go-build \
    go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api

# 运行阶段：distroless（最小镜像，不含shell）
FROM gcr.io/distroless/static-debian12 AS runtime
USER 65532:65532   # non-root
WORKDIR /app
COPY --from=builder /out/api /app/api
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
EXPOSE 8080
# 注意：distroless 无法使用 curl/wget 设置 Docker HEALTHCHECK；在 Kubernetes 中以 probes 代替
ENTRYPOINT ["/app/api"]
```

```dockerfile
# Dockerfile.api.alpine
# 构建阶段：go1.22-alpine，CGO=0
FROM golang:1.22-alpine AS builder
RUN apk add --no-cache build-base ca-certificates tzdata upx
ENV CGO_ENABLED=0 GOOS=linux GOARCH=amd64
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN --mount=type=cache,target=/root/.cache/go-build \
    go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api && upx /out/api || true

# 运行阶段：alpine，提供 HEALTHCHECK 与非root用户
FROM alpine:3.20 AS runtime
RUN addgroup -S app && adduser -S -G app app
WORKDIR /app
COPY --from=builder /out/api /app/api
RUN apk add --no-cache ca-certificates curl tzdata && chmod +x /app/api
USER app
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD curl -fsS http://127.0.0.1:8080/healthz || exit 1
ENTRYPOINT ["/app/api"]
```

#### 18.1.2 前端（React）Dockerfile 与 Nginx 配置（gzip/缓存头）
```dockerfile
# Dockerfile.web
# 构建阶段：node:lts-alpine
FROM node:lts-alpine AS build
WORKDIR /app
COPY web/package*.json ./
RUN npm ci --legacy-peer-deps
COPY web/ ./
RUN npm run build

# 运行阶段：nginx:alpine 提供静态资源
FROM nginx:alpine
COPY deploy/nginx.conf /etc/nginx/nginx.conf
COPY --from=build /app/build /usr/share/nginx/html
EXPOSE 8081
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD wget -q -O- http://127.0.0.1:8081/healthz || exit 1
```

```nginx
# deploy/nginx.conf
worker_processes 1;
events { worker_connections 1024; }
http {
  include       /etc/nginx/mime.types;
  default_type  application/octet-stream;
  sendfile      on;
  keepalive_timeout 65;

  gzip on;
  gzip_comp_level 5;
  gzip_types text/plain text/css application/json application/javascript application/octet-stream image/svg+xml;

  server {
    listen 8081;
    server_name _;

    location = /healthz { return 200 'ok'; add_header Content-Type text/plain; }

    location / {
      root   /usr/share/nginx/html;
      try_files $uri /index.html;
    }
    location ~* \.(js|css|png|jpg|svg)$ {
      expires 7d;
      add_header Cache-Control "public, max-age=604800";
    }
  }
}
```

#### 18.1.3 docker-compose.yml（开发/小规模部署）
```yaml
version: "3.9"
services:
  api:
    # 任选一种运行镜像：alpine 更适合本地/Compose（有 HEALTHCHECK）；distroless 更小巧（K8s 建议）
    build:
      context: .
      dockerfile: Dockerfile.api.alpine
    image: share-my-status-api:latest
    env_file:
      - .env
    environment:
      HTTP_PORT: 8080
      DEFAULT_TZ: ${DEFAULT_TZ}
      DB_DSN: ${DB_DSN}
      REDIS_URL: ${REDIS_URL}
      SECRET_KEY: ${SECRET_KEY}
      SHARING_KEY: ${SHARING_KEY}
    ports:
      - "8080:8080"
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_started
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://localhost:8080/healthz"]
      interval: 30s
      timeout: 3s
      retries: 3
    networks:
      - appnet

  web:
    build:
      context: .
      dockerfile: Dockerfile.web
    image: share-my-status-web:latest
    ports:
      - "8081:8081"
    depends_on:
      api:
        condition: service_healthy
    networks:
      - appnet

  mysql:
    image: mysql:8.0
    command: ["--default-authentication-plugin=mysql_native_password", "--character-set-server=utf8mb4", "--collation-server=utf8mb4_0900_ai_ci"]
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
      - ./db/init:/docker-entrypoint-initdb.d:ro
    ports:
      - "3306:3306"
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 30s
      timeout: 5s
      retries: 10
    networks:
      - appnet

  redis:
    image: redis:7-alpine
    command: ["redis-server", "--appendonly", "no"]  # 默认不持久化；如需AOF改为 "yes"
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 3s
      retries: 10
    networks:
      - appnet

  redis-exporter:
    image: oliver006/redis_exporter:latest
    environment:
      REDIS_ADDR: redis:6379
    ports:
      - "9121:9121"
    depends_on:
      - redis
    networks:
      - appnet

  mysqld-exporter:
    image: prom/mysqld-exporter:latest
    environment:
      DATA_SOURCE_NAME: ${MYSQL_USER}:${MYSQL_PASSWORD}@(mysql:3306)/${MYSQL_DATABASE}
    ports:
      - "9104:9104"
    depends_on:
      - mysql
    networks:
      - appnet

  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./monitoring/prometheus/rules:/etc/prometheus/rules:ro
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    depends_on:
      - api
      - redis-exporter
      - mysqld-exporter
    networks:
      - appnet

  alertmanager:
    image: prom/alertmanager:latest
    volumes:
      - ./monitoring/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
    ports:
      - "9093:9093"
    networks:
      - appnet

  grafana:
    image: grafana/grafana:latest
    environment:
      GF_SECURITY_ADMIN_USER: ${GRAFANA_ADMIN_USER}
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD}
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana/provisioning:/etc/grafana/provisioning:ro
    ports:
      - "3000:3000"
    networks:
      - appnet

networks:
  appnet:
    driver: bridge

volumes:
  mysql_data:
  prometheus_data:
  grafana_data:
```

#### 18.1.4 .env 示例（不要提交到仓库）
```
# 应用
APP_ENV=dev
DEFAULT_TZ=Asia/Shanghai
HTTP_PORT=8080

# 密钥（本地开发示例，生产务必改为K8s Secret注入）
SECRET_KEY=dev-secret-please-change
SHARING_KEY=dev-sharing-please-change

# 数据库
MYSQL_ROOT_PASSWORD=dev-root-pass
MYSQL_DATABASE=share_my_status
MYSQL_USER=app
MYSQL_PASSWORD=app-pass
DB_DSN=app:app-pass@tcp(mysql:3306)/share_my_status?charset=utf8mb4&parseTime=True&loc=Local

# Redis
REDIS_URL=redis://redis:6379

# Grafana
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin
```

#### 18.1.5 Prometheus 配置与规则示例
```yaml
# monitoring/prometheus/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ["alertmanager:9093"]

rule_files:
  - "/etc/prometheus/rules/*.yml"

scrape_configs:
  - job_name: "api"
    metrics_path: /metrics
    static_configs:
      - targets: ["api:8080"]
  - job_name: "redis"
    static_configs:
      - targets: ["redis-exporter:9121"]
  - job_name: "mysql"
    static_configs:
      - targets: ["mysqld-exporter:9104"]
```

```yaml
# monitoring/prometheus/rules/api.yml
groups:
- name: api.rules
  rules:
  - alert: ApiHighErrorRate
    expr: (sum(rate(http_requests_total{service="api",status=~"5.."}[5m])) / sum(rate(http_requests_total{service="api"}[5m]))) > 0.05
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "API 5xx 错误率超过 5%（持续 5m）"
      description: "检查上游依赖与最近发布，关注 rate(http_requests_total) 与异常日志。"

  - alert: ApiHighLatencyP95
    expr: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{service="api"}[5m])) by (le)) > 1.0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "API P95 延迟 > 1s"
      description: "关注慢接口与资源瓶颈，必要时扩容或降级。"

  - alert: WsConnectionsDrop
    expr: (increase(ws_disconnect_total[5m]) / (increase(ws_connect_total[5m]) + 1)) > 0.2
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "WS 断连率在 10 分钟内 > 20%"
      description: "检查房间广播与心跳设置、网关健康。"
```

```yaml
# monitoring/prometheus/rules/redis.yml
groups:
- name: redis.rules
  rules:
  - alert: RedisDown
    expr: redis_up == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Redis 不可用"
      description: "redis_exporter 指示 Redis down。"

  - alert: RedisConnectedClientsLow
    expr: redis_connected_clients < 1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Redis 客户端连接数异常偏低"
      description: "检查网络、权限或服务状态。"
```

```yaml
# monitoring/prometheus/rules/mysql.yml
groups:
- name: mysql.rules
  rules:
  - alert: MySQLSlowQueriesHigh
    expr: increase(mysql_global_status_slow_queries[5m]) > 10
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "MySQL 慢查询 5 分钟 > 10"
      description: "检查索引、执行计划与热点表。"

  - alert: MySQLQPSHigh
    expr: sum(rate(mysql_global_status_queries[1m])) > 2000
    for: 5m
    labels:
      severity: info
    annotations:
      summary: "MySQL QPS > 2000（信息告警）"
      description: "评估当前容量与缓存命中率，必要时扩容。"

  # 需要 Node Exporter 提供磁盘指标；如未启用请跳过该规则
  - alert: MySQLDiskUsageHigh
    expr: (node_filesystem_size_bytes{mountpoint="/var/lib/mysql"} - node_filesystem_avail_bytes{mountpoint="/var/lib/mysql"}) / node_filesystem_size_bytes{mountpoint="/var/lib/mysql"} > 0.85
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "MySQL 数据卷使用率 > 85%"
      description: "请扩容 PVC 或清理过期数据。"
```

```yaml
# monitoring/alertmanager/alertmanager.yml
route:
  group_by: ["alertname"]
  group_wait: 10s
  group_interval: 1m
  repeat_interval: 4h
  receiver: default
receivers:
- name: default
  # 可按需配置 webhook/email/slack 等接收器
  # webhook_configs:
  # - url: "http://ops-notify/receptor"
```

> **Grafana 看板与接入**：
> - 默认管理账号：`admin/admin`（**首次登录后请立刻修改密码**）。
> - 建议导入看板（文件占位）：`monitoring/grafana/dashboards/api-overview.json`、`db-overview.json`、`redis-overview.json`。
> - Prometheus 数据源：`http://prometheus:9090`；Alertmanager：`http://alertmanager:9093`。

### 18.2 Kubernetes Helm 部署方案
#### 18.2.1 Chart 目录结构（示例名：share-my-status）
```
share-my-status/
  Chart.yaml
  values.yaml
  templates/
    deployment-api.yaml
    service-api.yaml
    deployment-web.yaml
    service-web.yaml
    ingress-web.yaml
    configmap-web-nginx.yaml
    secret-app.yaml
    statefulset-mysql.yaml
    service-mysql.yaml
    deployment-redis.yaml
    service-redis.yaml
    servicemonitor-api.yaml
    prometheusrules.yaml
    hpa-api.yaml
    pdb-api.yaml
```

#### 18.2.2 values.yaml 示例（核心配置）
```yaml
# values.yaml（摘要）
global:
  imagePullPolicy: IfNotPresent
  monitoring:
    enabled: true
    prometheusOperator: true

api:
  image:
    repository: share-my-status/api
    tag: v0.1.0
  service:
    port: 8080
  env:
    HTTP_PORT: 8080
    DEFAULT_TZ: Asia/Shanghai
    REDIS_URL: redis://redis:6379
    DB_DSN: app:app-pass@tcp(mysql:3306)/share_my_status?charset=utf8mb4&parseTime=True&loc=Local
  secret:
    SECRET_KEY: ""          # 以 Secret 注入
    FEISHU_APP_ID: ""
    FEISHU_APP_SECRET: ""
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    readOnlyRootFilesystem: true
  monitoring:
    serviceMonitor:
      enabled: true
      path: /metrics

web:
  image:
    repository: share-my-status/web
    tag: v0.1.0
  service:
    port: 8081
  ingress:
    enabled: true
    className: nginx
    host: status.example.com
    tls:
      enabled: true
      secretName: status-tls

mysql:
  enabled: true
  image: mysql:8.0
  persistence:
    enabled: true
    storageClass: ""
    size: 20Gi
  auth:
    rootPassword: ""
    database: share_my_status
    username: app
    password: ""
  initSQL:
    enabled: true
    configMapName: mysql-init-sql

redis:
  image: redis:7-alpine
  persistence:
    enabled: false
  auth:
    passwordSecretName: redis-pass

hpa:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  cpuTargetUtilizationPercentage: 70

pdb:
  enabled: true
  maxUnavailable: 1
```

#### 18.2.3 后端 Deployment 与 Service（片段）
```yaml
# templates/deployment-api.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "sms.apiName" . }}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: {{ include "sms.apiName" . }}
  template:
    metadata:
      labels:
        app: {{ include "sms.apiName" . }}
    spec:
      securityContext:
        runAsNonRoot: true
        fsGroup: 65532
      containers:
      - name: api
        image: {{ .Values.api.image.repository }}:{{ .Values.api.image.tag }}
        imagePullPolicy: {{ .Values.global.imagePullPolicy }}
        ports:
        - name: http
          containerPort: {{ .Values.api.service.port }}
        env:
        - name: HTTP_PORT
          value: "{{ .Values.api.env.HTTP_PORT }}"
        - name: DEFAULT_TZ
          value: "{{ .Values.api.env.DEFAULT_TZ }}"
        - name: REDIS_URL
          value: "{{ .Values.api.env.REDIS_URL }}"
        - name: DB_DSN
          value: "{{ .Values.api.env.DB_DSN }}"
        - name: SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: SECRET_KEY
        - name: FEISHU_APP_ID
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: FEISHU_APP_ID
        - name: FEISHU_APP_SECRET
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: FEISHU_APP_SECRET
        readinessProbe:
          httpGet:
            path: /healthz
            port: http
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /healthz
            port: http
          initialDelaySeconds: 15
          periodSeconds: 20
        resources:
          requests:
            cpu: {{ .Values.api.resources.requests.cpu }}
            memory: {{ .Values.api.resources.requests.memory }}
          limits:
            cpu: {{ .Values.api.resources.limits.cpu }}
            memory: {{ .Values.api.resources.limits.memory }}
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "sms.apiName" . }}
spec:
  selector:
    app: {{ include "sms.apiName" . }}
  ports:
  - name: http
    port: {{ .Values.api.service.port }}
    targetPort: http
```

#### 18.2.4 前端 Deployment 与 Nginx 配置（片段）
```yaml
# templates/deployment-web.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "sms.webName" . }}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: {{ include "sms.webName" . }}
  template:
    metadata:
      labels:
        app: {{ include "sms.webName" . }}
    spec:
      containers:
      - name: web
        image: {{ .Values.web.image.repository }}:{{ .Values.web.image.tag }}
        ports:
        - name: http
          containerPort: {{ .Values.web.service.port }}
        volumeMounts:
        - name: nginx-conf
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
        readinessProbe:
          httpGet:
            path: /healthz
            port: http
          initialDelaySeconds: 5
        livenessProbe:
          httpGet:
            path: /healthz
            port: http
          initialDelaySeconds: 15
      volumes:
      - name: nginx-conf
        configMap:
          name: web-nginx-conf
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-nginx-conf
data:
  nginx.conf: |
    worker_processes 1;
    events { worker_connections 1024; }
    http {
      include /etc/nginx/mime.types;
      default_type application/octet-stream;
      sendfile on;
      keepalive_timeout 65;
      gzip on;
      gzip_comp_level 5;
      gzip_types text/plain text/css application/json application/javascript application/octet-stream image/svg+xml;
      server {
        listen {{ .Values.web.service.port }};
        server_name _;
        location = /healthz { return 200 'ok'; add_header Content-Type text/plain; }
        location / { root /usr/share/nginx/html; try_files $uri /index.html; }
        location ~* \.(js|css|png|jpg|svg)$ { expires 7d; add_header Cache-Control "public, max-age=604800"; }
      }
    }
```

```yaml
# templates/ingress-web.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "sms.webName" . }}
  annotations:
    kubernetes.io/ingress.class: {{ .Values.web.ingress.className | quote }}
spec:
  tls:
  - hosts: [{{ .Values.web.ingress.host | quote }}]
    secretName: {{ .Values.web.ingress.tls.secretName }}
  rules:
  - host: {{ .Values.web.ingress.host }}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: {{ include "sms.webName" . }}
            port:
              number: {{ .Values.web.service.port }}
```

#### 18.2.5 数据库与缓存（MySQL StatefulSet + PVC、Redis）
```yaml
# templates/statefulset-mysql.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ include "sms.mysqlName" . }}
spec:
  serviceName: {{ include "sms.mysqlName" . }}
  replicas: 1
  selector:
    matchLabels:
      app: {{ include "sms.mysqlName" . }}
  template:
    metadata:
      labels:
        app: {{ include "sms.mysqlName" . }}
    spec:
      containers:
      - name: mysql
        image: {{ .Values.mysql.image }}
        args: ["--default-authentication-plugin=mysql_native_password", "--character-set-server=utf8mb4", "--collation-server=utf8mb4_0900_ai_ci"]
        ports:
        - name: mysql
          containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-auth
              key: rootPassword
        - name: MYSQL_DATABASE
          value: {{ .Values.mysql.auth.database | quote }}
        - name: MYSQL_USER
          value: {{ .Values.mysql.auth.username | quote }}
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-auth
              key: password
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
        - name: init-sql
          mountPath: /docker-entrypoint-initdb.d
        readinessProbe:
          exec:
            command: ["mysqladmin","ping","-h","127.0.0.1"]
          initialDelaySeconds: 20
      volumes:
      - name: init-sql
        configMap:
          name: {{ .Values.mysql.initSQL.configMapName }}
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: {{ .Values.mysql.persistence.storageClass | quote }}
      resources:
        requests:
          storage: {{ .Values.mysql.persistence.size | quote }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "sms.mysqlName" . }}
spec:
  selector:
    app: {{ include "sms.mysqlName" . }}
  ports:
  - name: mysql
    port: 3306
    targetPort: mysql
```

```yaml
# templates/deployment-redis.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "sms.redisName" . }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {{ include "sms.redisName" . }}
  template:
    metadata:
      labels:
        app: {{ include "sms.redisName" . }}
    spec:
      containers:
      - name: redis
        image: {{ .Values.redis.image }}
        args: ["--appendonly","no"]
        ports:
        - name: redis
          containerPort: 6379
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ .Values.redis.auth.passwordSecretName }}
              key: password
---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "sms.redisName" . }}
spec:
  selector:
    app: {{ include "sms.redisName" . }}
  ports:
  - name: redis
    port: 6379
    targetPort: redis
```

#### 18.2.6 监控与告警（ServiceMonitor、PrometheusRule）
```yaml
# templates/servicemonitor-api.yaml
{{- if and .Values.global.monitoring.enabled .Values.api.monitoring.serviceMonitor.enabled -}}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "sms.apiName" . }}
spec:
  selector:
    matchLabels:
      app: {{ include "sms.apiName" . }}
  endpoints:
  - port: http
    path: {{ .Values.api.monitoring.serviceMonitor.path }}
    interval: 15s
{{- end }}
```

```yaml
# templates/prometheusrules.yaml
{{- if .Values.global.monitoring.enabled -}}
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: sms-rules
spec:
  groups:
  - name: api.rules
    rules:
    - alert: ApiHighErrorRate
      expr: (sum(rate(http_requests_total{service="api",status=~"5.."}[5m])) / sum(rate(http_requests_total{service="api"}[5m]))) > 0.05
      for: 5m
      labels: { severity: warning }
      annotations: { summary: "API 5xx 错误率 > 5%", description: "检查发布与依赖" }
    - alert: ApiHighLatencyP95
      expr: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{service="api"}[5m])) by (le)) > 1.0
      for: 5m
      labels: { severity: warning }
      annotations: { summary: "API P95 > 1s" }
  - name: redis.rules
    rules:
    - alert: RedisDown
      expr: redis_up == 0
      for: 1m
      labels: { severity: critical }
      annotations: { summary: "Redis 不可用" }
  - name: mysql.rules
    rules:
    - alert: MySQLSlowQueriesHigh
      expr: increase(mysql_global_status_slow_queries[5m]) > 10
      for: 5m
      labels: { severity: warning }
      annotations: { summary: "MySQL 慢查询偏高" }
{{- end }}
```

#### 18.2.7 HPA 与 PDB（片段）
```yaml
# templates/hpa-api.yaml
{{- if .Values.hpa.enabled -}}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "sms.apiName" . }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "sms.apiName" . }}
  minReplicas: {{ .Values.hpa.minReplicas }}
  maxReplicas: {{ .Values.hpa.maxReplicas }}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ .Values.hpa.cpuTargetUtilizationPercentage }}
{{- end }}
```

```yaml
# templates/pdb-api.yaml
{{- if .Values.pdb.enabled -}}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "sms.apiName" . }}
spec:
  maxUnavailable: {{ .Values.pdb.maxUnavailable }}
  selector:
    matchLabels:
      app: {{ include "sms.apiName" . }}
{{- end }}
```

#### 18.2.8 灰度与发布
```bash
# 安装（或升级）到命名空间 sms
helm upgrade --install sms ./share-my-status -n sms \
  -f values.yaml \
  --create-namespace

# 查看资源与探针状态
kubectl -n sms get deploy,sts,svc,ingress,pdb,hpa
kubectl -n sms describe deploy/sms-api

# 回滚
helm rollback sms 1 -n sms
```

> **节点调度与发布健康**：
> - **滚动升级**：Deployment 默认 `maxUnavailable: 25%`；按需在 `strategy` 中调整。
> - **节点亲和与污点容忍**：在 Pod `affinity` 与 `tolerations` 中指定（如API部署到无盘节点，MySQL到有盘节点）。
> - **健康门槛**：在 `readinessProbe/livenessProbe` 中设置；PDB 保证有存活副本；必要时设置 `minReadySeconds`。

### 18.3 环境变量与密钥管理
- **本地（开发）**：使用 `.env`（dotenv）管理，**不要提交到仓库**；Compose 通过 `env_file` 注入。

- **生产（集群）**：通过 **Kubernetes Secret** 注入（`secret-app.yaml`/`mysql-auth`/`redis-pass`），仅以环境变量在容器内可见；审计与轮转通过平台工具完成。

### 18.4 数据与存储策略
- **MySQL 8.0**：使用 PVC（`storageClass` 可参数化）；初始化 SQL 挂载 `docker-entrypoint-initdb.d` 或 K8s `ConfigMap`；建议每日备份（**CronJob**）与保留策略（至少 7 天）。

- **Redis**：默认**不持久化**（AOF=off）；如需可靠队列或离线数据，开启 AOF 并设置 `persistence.enabled: true`；连接密码通过 Secret 注入。

- **监控持久化**：Prometheus 与 Grafana 挂载数据卷；Prometheus 规则与 Alertmanager 路由以挂载文件管理。

### 18.5 监控与报警清单（落地）
- **采集**：API `/metrics`（HTTP 请求计数与耗时、WS 连接计数、Redis/MySQL客户端错误计数等）；`redis_exporter`；`mysqld_exporter`；（可选）`node_exporter`。

- **Grafana 看板**：API 概览、DB 概览、Redis 概览（文件占位）；统一数据源 `Prometheus`。

- **Alertmanager 规则**：
	- API：**错误率**、**延迟 P95**、**WS 断连率**。
	- Redis：**redis_up**、连接数异常。
	- MySQL：**慢查询**、**QPS 阈值**、（可选）**数据卷使用率**。

### 18.6 可操作指引
- **本地快速起服务**：
	1. 在项目根目录准备 `.env`（避免提交仓库）。
	2. 在 `db/init/` 放置初始化 SQL（文档中的 DDL）。
	3. 执行 **docker-compose up -d**；等待 `mysql` 健康后 `api` 与 `web` 进入 `healthy`。
	4. 访问 `http://localhost:8081`；后端健康检查 `http://localhost:8080/healthz`，指标 `http://localhost:8080/metrics`。
	5. Grafana 默认 `http://localhost:3000`，账号 `admin/admin`（**首次登录后立刻修改密码**）。

- **集群部署**：
	1. 编辑 `values.yaml`，填充镜像、Secret、数据库与缓存连接、Ingress 域名与 TLS。
	2. 执行 **helm upgrade --install** 安装到命名空间 `sms`。
	3. 验证 Service、Ingress、`/healthz` 与 `/metrics`；在 Grafana 导入看板文件并连接 Prometheus 数据源。
	4. 启用 HPA 与 PDB，观察滚动升级时的探针与副本健康；必要时回滚。

## 19 监控与告警
**新增指标**：

- **授权率**（音乐统计授权/总用户）。

- **封面哈希命中率**（exists 命中/查询总数）。

- **机器人指令成功率**与失败原因分布（未绑定/频控/签名失败/服务端错误）。

**链路健康**：采集上报成功率、WS 在线数与重连率、**飞书事件处理成功率**。

**SLI/SLO**：

- 上报→推送端到端延迟 P95、P99；WS 断线率；飞书预览 P95。

**日志与追踪字段**：

- 结构化日志需包含 `sharingKey`、`roomId`、`idempotencyKey`、`coverHash`、`activity.label`、`tz`、`window.type`。

**告警**：

- WS 重连率异常、房间人数异常、飞书事件处理 5xx、Redis 连接失败、封面命中率跌破阈值、机器人命令连番失败。

## 20 错误处理与降级
**封面上传失败**：

- 回退到占位图；事件体仅保留 `coverHash` 与失败标记；前端不阻塞状态展示。

**授权缺失**：

- 统计接口返回 `UNAUTHORIZED_STAT_STORAGE` 与提示；前端引导用户在客户端开启授权。

**机器人操作失败**：

- 明确提示（未绑定/频控/签名失败）；对安全操作提供**确认二次交互**（如轮转 SecretKey）。

**链路中断**：

- 前端标记离线并**保留最近快照**；恢复后补齐差异。

**第三方失败**：

- 飞书事件处理失败时返回兜底文案；频控命中时优先返回缓存。

## 21 测试与发布
**统计正确性**：

- 滚动与日历窗口边界校验（含跨月/跨年），时区归一与示例值（2025-10-03 本月/今年）。

- TopN 稳定性（并列与排序）。

**哈希去重正确性**：

- 同一封面多次上报仅一次存储；指针一致性与规格派生正确。

**白名单覆盖**：

- 指定播放器事件采集正确，非白名单不采集；CPU 与 I/O 降幅评估。

**授权与撤销**：

- 客户端授权弹窗与服务端授权状态一致；撤销后不新增，保留期与软删/硬删行为验证。

**端到端与压力**：

- WS 并发与房间广播压力；上报风暴去抖效果；封面查询 QPS 与命中率达标。

## 22 路线图与迭代
- **MVP**：系统状态与主流播放器适配（采集到最小必要字段）、Web 实时页、飞书签名预览、密钥与撤销、速率限制与基础监控。

- **统计面板**：听歌统计接口上线后，前端补充汇总与 TopN 展示小组件。

- **多播放器适配**：QQ 音乐、网易云等本地会话适配与白名单完善（注意仅生成必要字段）。

- **活动映射增强**：跨平台窗口识别与语义库扩充，用户自定义规则导入导出（上报仅 label）。

- **移动端支持**：iOS/Android 客户端采集与展示（同样遵循最小化字段）。

- **开放 API**：对授权用户开放只读统计查询与最近状态读取接口。

