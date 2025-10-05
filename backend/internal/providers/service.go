package providers

import (
	"share-my-status/internal/service"
	"github.com/redis/go-redis/v9"
	"gorm.io/gorm"
)

// ProvideServiceManager 提供服务管理器实例
func ProvideServiceManager(db *gorm.DB, redisClient *redis.Client) *service.ServiceManager {
	return &service.ServiceManager{}
}