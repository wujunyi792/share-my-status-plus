include "./state_service.thrift"
include "./stats_service.thrift"
include "./cover_service.thrift"
include "./websocket_service.thrift"

namespace go share_my_status

// 通过继承的方式组织各个服务
service StateService extends state_service.StateService {}
service StatsService extends stats_service.StatsService {}
service CoverService extends cover_service.CoverService {}
service WebSocketService extends websocket_service.WebSocketService {}
