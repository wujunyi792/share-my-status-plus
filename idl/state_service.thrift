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

// 状态服务定义
service StateService {
    // 批量上报状态
    BatchReportResponse BatchReport(1: BatchReportRequest req) (api.post="/v1/state/report");
    
    // 查询最新状态
    QueryStateResponse QueryState(1: QueryStateRequest req) (api.get="/v1/state/query");
}