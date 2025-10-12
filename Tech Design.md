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

- `/public on|off`：开启/关闭 **Web 公开访问**（公开页访问授权）。

- `/stat on|off`：开启/关闭 **音乐统计授权**（历史数据存储授权）。

- `/rotate secret-key`：轮转 **SecretKey**（客户端需重新配置）。

- `/rotate sharing-key`：轮转 **SharingKey**（分享链接立即失效，WS 房间强制关闭）。

- `/info`：查看当前用户信息（包括密钥、链接、授权状态等）。

- `/config`：返回推荐的客户端配置 JSON（包括默认活动分组、音乐应用白名单等）。

- `/help`：显示帮助信息。

**中文别名命令**：

- `开启公开访问` / `关闭公开访问`
- `授权音乐统计` / `取消授权音乐统计`
- `查看我的信息`
- `轮转数据上报密钥` / `轮转分享链接`
- `推荐配置`
- `帮助`

**交互流程**：

1. 用户在机器人会话中输入命令或中文别名。

2. 机器人通过飞书 SDK 长链接会话接收消息事件（P2MessageReceiveV1）。

3. 解析命令，获取或创建用户（通过 OpenID）。

4. 执行相应操作：
   - 更新用户设置（`user_settings`表）
   - 轮转密钥（更新`users`表）
   - 生成推荐配置 JSON（包含活动分组、白名单等）

5. 通过飞书 API 回复消息：
   - 普通命令使用文本消息回复
   - `/config` 命令使用富文本(Post)回复，包含 JSON 代码块

**安全校验与权限**：

- 机器人通过飞书 OpenID 自动关联用户，首次交互时自动创建用户记录。

- 命令仅作用于**本人资源**（通过 OpenID 识别）。

- 所有操作记录到日志系统，包含操作人、时间、操作类型。

- 失败提示清晰可执行（如"当前未开启公开授权"、"用法错误"）。

## 12 服务端设计
**接口设计**（所有接口均以 `/api/v1` 为前缀）：

- 上报：`POST /api/v1/state/report`（支持批量）。

- 查询最近：`GET /api/v1/state/query?sharingKey=...`。

- 统计：`POST /api/v1/stats/query`（需授权）。

- WebSocket：`GET /api/v1/ws?sharingKey=...`。

- 客户端版本检查：`GET /api/v1/client/check-version`（查询最新客户端版本信息）。

- 飞书事件处理：在**官方 SDK 长链接会话**内接收**链接预览拉取事件**和**消息接收事件**，内部 handler 解析请求并执行预览渲染、命令处理与必要的**预览更新能力**，遵循幂等与频控。**注意**：出于性能考虑，飞书链接预览**暂不支持聚合统计变量渲染**，仅返回实时状态（音乐、系统、活动）。

- 封面：`GET /api/v1/cover/exists?md5=...`、`POST /api/v1/cover/upload`、`GET /api/v1/cover/:hash?size=...`。

- 分享链接重定向：`GET /s/:sharingKey`（重定向到 Web 页面或自定义目标）。

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
  secret_key VARBINARY(64) NOT NULL COMMENT '客户端上报密钥（服务端存储原文，用于认证）',
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
  user_id BIGINT UNSIGNED NOT NULL PRIMARY KEY COMMENT '用户ID（FK）',
  settings JSON NOT NULL COMMENT '用户隐私与功能开关（JSON）',
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  CONSTRAINT fk_settings_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='用户隐私设置（JSON）';

-- 当前状态快照（JSON）
CREATE TABLE current_state (
  user_id BIGINT UNSIGNED NOT NULL PRIMARY KEY COMMENT '用户ID（FK）',
  snapshot JSON NOT NULL COMMENT '当前状态快照（System/Music/Activity）',
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  KEY ix_state_updated (updated_at),
  CONSTRAINT fk_current_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='当前状态快照（JSON）';

-- 历史状态流（JSON + 记录时间）
CREATE TABLE state_history (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '历史记录主键',
  user_id BIGINT UNSIGNED NOT NULL COMMENT '用户ID（FK）',
  recorded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '记录时间',
  snapshot JSON NOT NULL COMMENT '状态快照（JSON）',
  KEY ix_hist_user_time (user_id, recorded_at),
  CONSTRAINT fk_history_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='历史状态流水（JSON）';

-- 封面资源去重（MD5 主键）
CREATE TABLE cover_assets (
  cover_hash CHAR(32) PRIMARY KEY COMMENT 'MD5 of decoded image bytes，用于封面去重',
  asset JSON NOT NULL COMMENT '封面内容 JSON，包含字段：b64（base64字符串）、contentType（MIME类型）、size（字节大小）、uploadTime（上传时间戳）、storageType（固定为"base64"）',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='封面资源（JSON 格式存储）';

-- 聚合统计结果（JSON；支持窗口类型与起止时间）
-- 注意：此表暂未在当前实现中使用，统计功能计划在后续版本实现
CREATE TABLE music_stats (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '统计主键',
  user_id BIGINT UNSIGNED NOT NULL COMMENT '用户ID（FK）',
  window_type ENUM('rolling_3d','rolling_7d','month_to_date','year_to_date','custom') NOT NULL COMMENT '窗口类型',
  tz VARCHAR(32) NOT NULL DEFAULT 'Asia/Shanghai' COMMENT '时区',
  start_time TIMESTAMP NOT NULL COMMENT '窗口开始',
  end_time TIMESTAMP NOT NULL COMMENT '窗口结束',
  stats JSON NOT NULL COMMENT '统计载荷（JSON：plays/uniqueTracks/topArtists/topTracks）',
  UNIQUE KEY uk_user_window (user_id, window_type, start_time, end_time),
  CONSTRAINT fk_stats_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='音乐统计结果（JSON）';
```

-- 客户端版本信息表
CREATE TABLE client_versions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '版本记录主键',
  platform VARCHAR(16) NOT NULL COMMENT '平台：windows、macos',
  version VARCHAR(32) NOT NULL COMMENT '版本号',
  build_number INT NOT NULL COMMENT '构建号',
  download_url VARCHAR(255) NOT NULL COMMENT '下载链接',
  release_note TEXT COMMENT '发布说明',
  force_update TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否强制更新',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  KEY ix_platform (platform)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='客户端版本信息';
```

**主键与索引建议**：

- `users`：`id` 自增主键；`open_id`、`secret_key`、`sharing_key` 唯一索引，便于查找与撤销。

- `user_settings`：`user_id` 主键关联 `users.id`；存储用户隐私设置（JSON格式）。

- `current_state`：`user_id` 主键关联 `users.id`；对 `updated_at` 建索引用于时间范围查询。

- `state_history`：`(user_id, recorded_at)` 复合索引，用于按用户和时间查询历史记录。

- `cover_assets`：`cover_hash` 主键（MD5）；`asset` JSON 包含 `b64`（base64字符串）、`contentType`（MIME类型）、`size`（字节大小）、`uploadTime`（上传时间戳）、`storageType`（固定为"base64"）；结合 CDN 缓存策略按访问路径控制缓存与清理。

- `music_stats`：`uk_user_window` 唯一约束避免重复窗口（暂未启用，计划后续版本实现）。

- `client_versions`：`platform` 索引用于快速查询各平台最新版本。

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
// users（使用自增 id 作为主键，open_id 作为业务标识）
// =====================================
type User struct {
    ID         uint64    `gorm:"column:id;primaryKey;autoIncrement"`
    OpenID     string    `gorm:"column:open_id;type:varchar(64);uniqueIndex;not null"`
    SecretKey  []byte    `gorm:"column:secret_key;type:varbinary(64);uniqueIndex;not null"`
    SharingKey string    `gorm:"column:sharing_key;type:varchar(64);uniqueIndex;not null"`
    Status     int       `gorm:"column:status;type:tinyint;not null;default:1"`
    CreatedAt  time.Time `gorm:"column:created_at"`
    UpdatedAt  time.Time `gorm:"column:updated_at"`
}

// =====================================
// user_settings（JSONType[T]）
// =====================================
type SettingsPayload struct {
    PublicEnabled        bool   `json:"publicEnabled"`
    AuthorizedMusicStats bool   `json:"authorizedMusicStats"`
}

type UserSettings struct {
    UserID    uint64                              `gorm:"column:user_id;primaryKey"`
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
    UserID    uint64                                    `gorm:"column:user_id;primaryKey"`
    Snapshot  datatypes.JSONType[common.StatusSnapshot] `gorm:"column:snapshot;type:json;not null"`
    UpdatedAt time.Time                                 `gorm:"column:updated_at;autoUpdateTime"`
}

// =====================================
// state_history（JSONType[T]）
// =====================================
type StateHistory struct {
    ID         uint64                                    `gorm:"column:id;primaryKey;autoIncrement"`
    UserID     uint64                                    `gorm:"column:user_id;index:ix_hist_user_time,priority:1"`
    RecordedAt time.Time                                 `gorm:"column:recorded_at;index:ix_hist_user_time,priority:2"`
    Snapshot   datatypes.JSONType[common.StatusSnapshot] `gorm:"column:snapshot;type:json;not null"`
}

// =====================================
// cover_assets（JSON 格式存储封面信息）
// =====================================
type CoverAssetPayload struct {
    B64         string `json:"b64"`         // base64编码数据
    ContentType string `json:"contentType"` // MIME类型
    Size        int64  `json:"size"`        // 文件大小（字节）
    UploadTime  int64  `json:"uploadTime"`  // 上传时间戳
    StorageType string `json:"storageType"` // 固定为 "base64"
}

type CoverAsset struct {
    CoverHash string                                `gorm:"column:cover_hash;type:char(32);primaryKey" json:"coverHash"`
    Asset     datatypes.JSONType[CoverAssetPayload] `gorm:"column:asset;type:json;not null" json:"asset"`
    CreatedAt time.Time                             `gorm:"column:created_at"`
    UpdatedAt time.Time                             `gorm:"column:updated_at"`
}

// =====================================
// music_stats（JSONType[T]）- 计划后续版本实现
// =====================================
type MusicStatsPayload struct {
    Summary    *common.StatsSummary `json:"summary"`
    TopArtists []*common.TopItem    `json:"topArtists"`
    TopTracks  []*common.TopItem    `json:"topTracks"`
}

type MusicStats struct {
    ID         uint64                                `gorm:"column:id;primaryKey;autoIncrement"`
    UserID     uint64                                `gorm:"column:user_id;index:uk_user_window,unique,priority:1"`
    WindowType string                                `gorm:"column:window_type;type:enum('rolling_3d','rolling_7d','month_to_date','year_to_date','custom');index:uk_user_window,unique,priority:2"`
    Tz         string                                `gorm:"column:tz;size:32;not null"`
    StartTime  time.Time                             `gorm:"column:start_time;index:uk_user_window,unique,priority:3"`
    EndTime    time.Time                             `gorm:"column:end_time;index:uk_user_window,unique,priority:4"`
    Stats      datatypes.JSONType[MusicStatsPayload] `gorm:"column:stats;type:json;not null"`
    CreatedAt  time.Time                             `gorm:"column:created_at"`
    UpdatedAt  time.Time                             `gorm:"column:updated_at"`
}

// =====================================
// client_versions（客户端版本信息）
// =====================================
type ClientVersion struct {
    ID          uint64    `gorm:"column:id;primaryKey;autoIncrement"`
    Platform    string    `gorm:"column:platform;type:varchar(16);index:ix_platform"`
    Version     string    `gorm:"column:version;type:varchar(32);not null"`
    BuildNumber int       `gorm:"column:build_number;type:int;not null"`
    DownloadUrl string    `gorm:"column:download_url;type:varchar(255);not null"`
    ReleaseNote string    `gorm:"column:release_note;type:text"`
    ForceUpdate bool      `gorm:"column:force_update;type:tinyint(1);not null;default:false"`
    CreatedAt   time.Time `gorm:"column:created_at"`
    UpdatedAt   time.Time `gorm:"column:updated_at"`
}
```

> **封面资源存储策略**：
> - **JSON 格式存储**：`cover_assets.asset` 为 JSON，包含字段 `b64`（base64字符串）、`contentType`（MIME类型）、`size`（字节大小）、`uploadTime`（上传时间戳）、`storageType`（固定为"base64"）。
> - **哈希去重**：`cover_hash` 为**解码后的字节**的 MD5，作为主键实现去重。
> - **缓存策略**：通过 Redis 缓存资产信息（1小时）和存在性（5分钟），配合 CDN 提供快速访问。

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

**部署方式**：支持 **Docker Compose**（本地开发/小规模生产）与 **Kubernetes**（生产环境）两种方式。

**技术栈**：
- 后端：Golang 1.25 + Alpine 3.22（多阶段构建）
- 前端：Node 22 + pnpm + Vite + Nginx 1.25
- 数据库：MySQL latest / Redis 7.4-alpine
- 容器编排：Docker Compose / Kubernetes 原生 YAML

> **关键原则**：
> - **不要向仓库提交 .env 与任何密钥文件**
> - **健康检查路径**：后端 `/healthz`，前端 `/`
> - **非root用户运行**：所有容器使用非特权用户
> - **配置管理**：本地用 `.env`，K8s 用 ConfigMap + Secret

### 18.1 Docker Compose 部署

**镜像构建**：
- **后端**：Go 1.25-alpine 多阶段构建 → Alpine 3.22 运行（非root用户）
- **前端**：Node 22 + pnpm + Vite 构建 → Nginx 1.25-alpine 运行

**服务组成**（4个容器）：
- **share-backend**：Go 后端服务（端口 8080）
- **share-web**：Nginx + React 前端（端口 8888）
- **mysql**：MySQL latest（端口 3306，数据持久化到 `./docker/data/mysql`）
- **redis**：Redis 7.4-alpine（端口 6379，启用 AOF 持久化）

**Nginx 配置**：
- 静态资源服务（根路径 `/`）
- API 反向代理（`/api`, `/s`, `/link`）
- WebSocket 支持（`/api/v1/ws`，超时 600s）

**环境变量**（两个文件，不要提交仓库）：
- `.env`：Docker Compose 变量（数据库密码、Redis密码、端口等）
- `backend/.env`：后端应用配置（DB连接串、飞书凭证、日志、时区等）

**快速启动**：
```bash
make setup      # 准备 .env 文件
make dev-start  # 启动所有服务
make dev-logs   # 查看日志
```

### 18.2 Kubernetes 部署方案

**部署方式**：Kubernetes 原生 YAML 清单（位于 `k8s/` 目录）

**资源清单**（12个文件）：
- `namespace.yaml` - 命名空间（share-my-status）
- `configmap.yaml` - 应用配置（数据库连接、飞书凭证、日志等）
- `backend-deployment.yaml` - 后端部署（1副本，镜像 v1.0.3）
- `backend-service.yaml` - 后端服务（ClusterIP:8080）
- `frontend-deployment.yaml` - 前端部署（1副本，镜像 v1.0.3）
- `frontend-service.yaml` - 前端服务（ClusterIP:80）
- `frontend-nginx-configmap.yaml` - 前端 Nginx 配置
- `mysql-deployment.yaml` + `mysql-service.yaml` - MySQL 数据库
- `redis-deployment.yaml` + `redis-service.yaml` - Redis 缓存
- `ingress.yaml` - 路由配置（Higress + cert-manager + TLS）

**Ingress 配置**：
- **Controller**：Higress
- **TLS**：cert-manager 自动签发（letsencrypt）
- **域名**：lark.mjclouds.com、status-sharing.mjclouds.com
- **路径路由**：
  - `/api/v1/ws` → 后端（WebSocket）
  - `/api`, `/s`, `/link` → 后端
  - `/` → 前端

**资源配额**：
- 后端：100m CPU / 128Mi 内存（请求），500m / 512Mi（限制）
- 前端：50m CPU / 64Mi 内存（请求），300m / 256Mi（限制）

**部署命令**：
```bash
kubectl apply -f k8s/           # 一键部署
kubectl -n share-my-status get all  # 查看状态
```

### 18.3 Makefile 运维工具

项目提供 `Makefile` 简化日常操作，主要命令：
- `make setup` - 准备环境文件
- `make dev-start` / `make dev-stop` - 启动/停止开发环境
- `make deploy` - 部署到生产（拉取镜像并启动）
- `make prod-rebuild-backend` - 重建后端服务
- `make hz-update` - 从 IDL 更新代码
- `make wire` - 生成依赖注入代码

### 18.4 快速启动

**本地开发**：
```bash
make setup && make dev-start
# 访问 http://localhost:8888
```

**Kubernetes 部署**：
```bash
kubectl apply -f k8s/
kubectl -n share-my-status get pods
```

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

