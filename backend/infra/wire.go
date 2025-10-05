//go:build wireinject
// +build wireinject

package infra

import (
	"share-my-status/domain/cover"
	"share-my-status/domain/state"
	"share-my-status/domain/stats"
	"share-my-status/domain/user"
	"share-my-status/infra/cache"
	"share-my-status/infra/config"
	"share-my-status/infra/database"
	"share-my-status/infra/lark"
	"share-my-status/infra/scheduler"
	"share-my-status/infra/ws"

	"github.com/google/wire"
	larkSDK "github.com/larksuite/oapi-sdk-go/v3"
	larkws "github.com/larksuite/oapi-sdk-go/v3/ws"
	"github.com/redis/go-redis/v9"
	"gorm.io/gorm"
)

// AppDependencies 应用依赖结构
type AppDependencies struct {
	Config       *config.Config
	DB           *gorm.DB
	RedisClient  *redis.Client
	LarkClient   *larkSDK.Client
	LarkWSClient *larkws.Client
	WSClient     *ws.DistributedWebSocketService
	Scheduler    *scheduler.Scheduler

	CoverService *cover.CoverService
	UserService  *user.UserService
	StatsService *stats.StatsService
	StateService *state.StateService
}

// ProviderSet 定义所有Provider的集合
var ProviderSet = wire.NewSet(
	config.Init,
	database.Init,
	cache.Init,
	lark.InitLarkClient,
	lark.InitWsClient,
	lark.InitEventDispatcher,
	lark.NewEventHandler,
	ws.InitDistributedWebSocketService,
	cover.NewCoverService,
	user.NewUserService,
	stats.NewStatsService,
	state.NewStateService,
	scheduler.NewScheduler,
	wire.Struct(new(AppDependencies), "*"),
)

// InitializeApp 初始化应用依赖
func InitializeApp() (*AppDependencies, error) {
	wire.Build(ProviderSet)
	return &AppDependencies{}, nil
}

var GlobalAppDependencies *AppDependencies

func GetGlobalAppDependencies() *AppDependencies {
	return GlobalAppDependencies
}
