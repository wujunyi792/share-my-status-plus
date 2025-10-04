include "common.thrift"

namespace go share_my_status.state

// 批量上报请求
struct BatchReportRequest {
    1: required list<common.ReportEvent> events;
}

// 批量上报响应
struct BatchReportResponse {
    1: required common.BaseResponse base;
    2: optional i32 accepted;
    3: optional i32 deduped;
}

// 查询状态请求
struct QueryStateRequest {
    1: required string sharingKey;
}

// 查询状态响应
struct QueryStateResponse {
    1: required common.BaseResponse base;
    2: optional common.StatusSnapshot snapshot;
}
