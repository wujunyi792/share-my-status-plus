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
    4: optional string error;
    5: required i64 timestamp;
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

// WebSocket服务定义（用于生成相关结构，实际WebSocket处理在HTTP层）
service WebSocketService {
    // WebSocket连接建立（实际通过HTTP升级）
    WSConnectResponse Connect(1: WSConnectRequest req) (api.get="/v1/ws");
}