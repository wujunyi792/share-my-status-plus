package providers

import (
	"share-my-status/internal/config"
)

// ProvideConfig 提供配置实例
func ProvideConfig() (*config.Config, error) {
	if err := config.Init(); err != nil {
		return nil, err
	}
	return config.GlobalConfig, nil
}