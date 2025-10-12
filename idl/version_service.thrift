include "common.thrift"

namespace go share_my_status.version

// 客户端版本查询请求
struct CheckClientVersionRequest {
    1: required string platform;    // 平台：windows 或 macos
    2: required string version;     // 当前客户端语义化版本，例如 1.2.3
    3: required i32 build;          // 当前客户端构建号
}

// 最新版本信息
struct ClientVersionInfo {
    1: optional string platform;
    2: optional string version;
    3: optional i32 buildNumber;
    4: optional string downloadUrl;
    5: optional string releaseNote;
    6: optional bool forceUpdate;
    7: optional bool latest;
}

// 客户端版本查询响应
struct CheckClientVersionResponse {
    1: required common.BaseResponse base;
    2: optional ClientVersionInfo latest; // 有更新时返回最新版本信息；无更新时为null
}