package cache

import (
	"context"
	"share-my-status/infra/config"

	"github.com/redis/go-redis/v9"
	"github.com/sirupsen/logrus"
)

// Init 初始化Redis连接
func Init(cfg *config.Config) (*redis.Client, error) {
	redisCfg := cfg.Redis

	// 解析Redis URL
	opt, err := redis.ParseURL(redisCfg.URL)
	if err != nil {
		logrus.Errorf("Failed to parse Redis URL: %v", err)
		return nil, err
	}

	// 设置密码和数据库
	if redisCfg.Password != "" {
		opt.Password = redisCfg.Password
	}
	opt.DB = redisCfg.DB

	// 创建Redis客户端
	client := redis.NewClient(opt)

	// 测试连接
	ctx := context.Background()
	if err := client.Ping(ctx).Err(); err != nil {
		logrus.Errorf("Failed to connect to Redis: %v", err)
		return nil, err
	}

	logrus.Info("Redis connected successfully")
	return client, nil
}
