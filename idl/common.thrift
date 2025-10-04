namespace go share_my_status.common

// 基础响应结构
struct BaseResponse {
    1: required i32 code = 0;
    2: optional string message;
    3: optional list<string> warnings;
}

// 音乐信息结构
struct Music {
    1: optional string title;
    2: optional string artist;
    3: optional string album;
    4: optional string coverHash;
}

// 系统信息结构
struct System {
    1: optional double batteryPct;  // 0-1
    2: optional bool charging;
    3: optional double cpuPct;      // 0-1
    4: optional double memoryPct;   // 0-1
}

// 活动信息结构
struct Activity {
    1: required string label;  // 如：在工作、在写代码
}

// 上报事件结构
struct ReportEvent {
    1: required string version = "1";
    2: required i64 ts;  // 毫秒时间戳
    3: optional System system;
    4: optional Music music;
    5: optional Activity activity;
    6: optional string idempotencyKey;  // 幂等键
}

// 状态快照结构
struct StatusSnapshot {
    1: optional System system;
    2: optional Music music;
    3: optional Activity activity;
    4: required i64 lastUpdateTs;
}

// 时间窗口定义
enum WindowType {
    ROLLING_3D = 1,
    ROLLING_7D = 2,
    MONTH_TO_DATE = 3,
    YEAR_TO_DATE = 4,
    CUSTOM = 5
}

// 自定义时间窗口
struct CustomWindow {
    1: required i64 fromTs;
    2: required i64 toTs;
}

// 时间窗口信息
struct WindowInfo {
    1: required WindowType type;
    2: required string tz = "Asia/Shanghai";
    3: optional CustomWindow custom;
    4: optional i64 fromTs;  // 响应中回显实际窗口边界
    5: optional i64 toTs;
}

// TopN 项目
struct TopItem {
    1: required string name;
    2: required i32 count;
}

// 统计摘要
struct StatsSummary {
    1: optional i32 plays;
    2: optional i32 uniqueTracks;
}