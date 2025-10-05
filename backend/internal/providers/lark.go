package providers

import (
	"share-my-status/internal/config"
	lark "github.com/larksuite/oapi-sdk-go/v3"
	larkcore "github.com/larksuite/oapi-sdk-go/v3/core"
	"github.com/sirupsen/logrus"
)

// ProvideLarkClient 提供Lark客户端实例
func ProvideLarkClient(cfg *config.Config) *lark.Client {
	larkCfg := cfg.Lark

	client := lark.NewClient(larkCfg.AppID, larkCfg.AppSecret,
		lark.WithLogLevel(larkcore.LogLevelInfo),
	)

	logrus.Info("Lark client initialized successfully")
	return client
}