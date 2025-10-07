include "common.thrift"

namespace go share_my_status.websocket

// WebSocket消息类型
enum MessageType {
    PING = 1,
    PONG = 2,
    STATUS_UPDATE = 3,
    SNAPSHOT = 4,
    ERROR = 5
}

// WebSocket消息
struct WSMessage {
    1: required MessageType type;
    2: optional string id;  // 消息ID
    3: optional common.StatusSnapshot snapshot;
    4: optional string error;  // 错误消息
    5: required i64 timestamp;
    6: optional string errorCode;  // 错误代码
    7: optional bool retryable;  // 是否可重试
}

// WebSocket连接请求
struct WSConnectRequest {
    1: required string sharingKey;
}

// WebSocket连接响应
struct WSConnectResponse {
    1: required common.BaseResponse base;
    2: optional string sessionId;
}