//go:build wireinject
// +build wireinject

package providers

import (
	"share-my-status/internal/config"
	"share-my-status/internal/service"
	"github.com/google/wire"
	lark "github.com/larksuite/oapi-sdk-go/v3"
	"github.com/redis/go-redis/v9"
	"gorm.io/gorm"
)

// AppDependencies 应用依赖结构
type AppDependencies struct {
	Config         *config.Config
	DB             *gorm.DB
	RedisClient    *redis.Client
	LarkClient     *lark.Client
	ServiceManager *service.ServiceManager
}

// ProviderSet 定义所有Provider的集合
var ProviderSet = wire.NewSet(
	ProvideConfig,
	ProvideDatabase,
	ProvideRedis,
	ProvideLarkClient,
	ProvideServiceManager,
	wire.Struct(new(AppDependencies), "*"),
)

// InitializeApp 初始化应用依赖
func InitializeApp() (*AppDependencies, error) {
	wire.Build(ProviderSet)
	return &AppDependencies{}, nil
}