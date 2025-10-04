include "common.thrift"

namespace go share_my_status.stats

// 统计查询请求
struct StatsQueryRequest {
    1: required common.WindowInfo window;
    2: required list<string> metrics;  // ["plays", "unique_tracks", "top_artists", "top_tracks"]
    3: optional i32 topN = 10;
}

// 统计查询响应
struct StatsQueryResponse {
    1: required common.BaseResponse base;
    2: optional common.WindowInfo window;  // 回显实际窗口信息
    3: optional common.StatsSummary summary;
    4: optional list<common.TopItem> topArtists;
    5: optional list<common.TopItem> topTracks;
}
