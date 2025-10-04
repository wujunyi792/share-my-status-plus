include "./state_service.thrift"
include "./stats_service.thrift"
include "./cover_service.thrift"
include "./websocket_service.thrift"

namespace go share_my_status

// 通过继承的方式组织各个服务
service ShareMyStatus {
    // 查询封面是否存在
    cover_service.CoverExistsResponse CheckExists(1: cover_service.CoverExistsRequest req) (api.get="/v1/cover/exists");
    
    // 上传封面
    cover_service.CoverUploadResponse Upload(1: cover_service.CoverUploadRequest req) (api.post="/v1/cover/upload");
    
    // 获取封面
    cover_service.CoverGetResponse Get(1: cover_service.CoverGetRequest req) (api.get="/v1/cover/{hash}");

    // 批量上报状态
    state_service.BatchReportResponse BatchReport(1: state_service.BatchReportRequest req) (api.post="/v1/state/report");
    
    // 查询最新状态
    state_service.QueryStateResponse QueryState(1: state_service.QueryStateRequest req) (api.get="/v1/state/query");

    // 查询统计数据
    stats_service.StatsQueryResponse QueryStats(1: stats_service.StatsQueryRequest req) (api.post="/v1/stats/query");

    // WebSocket连接建立（实际通过HTTP升级）
    websocket_service.WSConnectResponse Connect(1: websocket_service.WSConnectRequest req) (api.get="/v1/ws");
}