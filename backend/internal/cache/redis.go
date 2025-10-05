package cache

import (
	"context"
	"time"

	"share-my-status/internal/config"

	"github.com/redis/go-redis/v9"
	"github.com/sirupsen/logrus"
)

var RedisClient *redis.Client

// Init 初始化Redis连接
func Init(ctx context.Context) error {
	cfg := config.GlobalConfig.Redis

	// 解析Redis URL
	opt, err := redis.ParseURL(cfg.URL)
	if err != nil {
		logrus.Errorf("Failed to parse Redis URL: %v", err)
		return err
	}

	// 设置密码和数据库
	if cfg.Password != "" {
		opt.Password = cfg.Password
	}
	opt.DB = cfg.DB

	// 创建Redis客户端
	RedisClient = redis.NewClient(opt)

	// 测试连接
	if err := RedisClient.Ping(ctx).Err(); err != nil {
		logrus.Errorf("Failed to connect to Redis: %v", err)
		return err
	}

	logrus.Info("Redis connected successfully")
	return nil
}

// Close 关闭Redis连接
func Close() error {
	if RedisClient != nil {
		return RedisClient.Close()
	}
	return nil
}

// GetClient 获取Redis客户端
func GetClient() *redis.Client {
	return RedisClient
}

// Set 设置键值对
func Set(ctx context.Context, key string, value interface{}, expiration time.Duration) error {
	return RedisClient.Set(ctx, key, value, expiration).Err()
}

// Get 获取值
func Get(ctx context.Context, key string) (string, error) {
	return RedisClient.Get(ctx, key).Result()
}

// Del 删除键
func Del(ctx context.Context, keys ...string) error {
	return RedisClient.Del(ctx, keys...).Err()
}

// Exists 检查键是否存在
func Exists(ctx context.Context, keys ...string) (int64, error) {
	return RedisClient.Exists(ctx, keys...).Result()
}

// Expire 设置键的过期时间
func Expire(ctx context.Context, key string, expiration time.Duration) error {
	return RedisClient.Expire(ctx, key, expiration).Err()
}

// Publish 发布消息到频道
func Publish(ctx context.Context, channel string, message interface{}) error {
	return RedisClient.Publish(ctx, channel, message).Err()
}

// Subscribe 订阅频道
func Subscribe(ctx context.Context, channels ...string) *redis.PubSub {
	return RedisClient.Subscribe(ctx, channels...)
}
