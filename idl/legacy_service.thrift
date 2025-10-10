include "./common.thrift"

namespace go share_my_status.legacy

// 旧版音乐数据结构（兼容旧版后端）
struct LegacyMusicData {
    1: required string artist;
    2: required string title;
    3: required string album;
    4: optional string duration;
    5: optional string artwork;  // base64编码的图片数据
}

// 旧版活动上报请求
struct LegacyActivityRequest {
    1: required string key;        // API密钥
    2: required string type;       // 活动类型，目前只支持"music"
    3: optional LegacyMusicData musicData;  // 音乐数据（当type为music时必填）
}

// 旧版活动上报响应
struct LegacyActivityResponse {
    1: required i32 error = 0;     // 错误码，0表示成功
    2: required string message = "success";  // 响应消息
}

// 链接跳转请求
struct LinkRedirectRequest {
    1: optional string r;  // 重定向URL参数
}

// 链接跳转响应
struct LinkRedirectResponse {}