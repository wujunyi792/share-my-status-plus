package config

import (
	"os"
	"strconv"
	"time"

	"github.com/joho/godotenv"
	"github.com/sirupsen/logrus"
)

// Config 应用配置
type Config struct {
	// 应用配置
	App AppConfig `json:"app"`
	// 数据库配置
	Database DatabaseConfig `json:"database"`
	// Redis配置
	Redis RedisConfig `json:"redis"`
	// 飞书配置
	Lark LarkConfig `json:"lark"`
	// 日志配置
	Log LogConfig `json:"log"`
	// 重定向配置
	Redirect RedirectConfig `json:"redirect"`
	// 加密配置（兼容旧版）
	LegacyCrypto LegacyConfig `json:"legacyCrypto"`
}

// AppConfig 应用配置
type AppConfig struct {
	Name        string `json:"name"`
	Version     string `json:"version"`
	Environment string `json:"environment"`
	Port        int    `json:"port"`
	Debug       bool   `json:"debug"`
	DefaultTZ   string `json:"defaultTz"`
}

// DatabaseConfig 数据库配置
type DatabaseConfig struct {
	DSN             string        `json:"dsn"`
	MaxIdleConns    int           `json:"maxIdleConns"`
	MaxOpenConns    int           `json:"maxOpenConns"`
	ConnMaxLifetime time.Duration `json:"connMaxLifetime"`
}

// RedisConfig Redis配置
type RedisConfig struct {
	URL      string `json:"url"`
	Password string `json:"password"`
	DB       int    `json:"db"`
}

// LarkConfig 飞书配置
type LarkConfig struct {
	AppID     string `json:"appId"`
	AppSecret string `json:"appSecret"`
}

// LogConfig 日志配置
type LogConfig struct {
	Level  string `json:"level"`
	Format string `json:"format"`
}

// RedirectConfig 重定向配置
type RedirectConfig struct {
	DefaultTarget string `json:"defaultTarget"` // 默认跳转目标，支持{SharingKey}占位符
}

// LegacyConfig 旧版兼容性配置
type LegacyConfig struct {
	Key             string `json:"key"`             // 加密密钥
	IV              string `json:"iv"`              // 初始化向量
	DefaultJumpLink string `json:"defaultJumpLink"` // /link接口默认跳转链接
}

// Init 初始化配置
func Init() (*Config, error) {
	// 加载环境变量文件
	if err := loadEnv(); err != nil {
		logrus.Warnf("Failed to load .env file: %v", err)
	}

	config := &Config{
		App: AppConfig{
			Name:        getEnv("APP_NAME", "share-my-status"),
			Version:     getEnv("APP_VERSION", "1.0.0"),
			Environment: getEnv("APP_ENV", "dev"),
			Port:        getEnvAsInt("HTTP_PORT", 8080),
			Debug:       getEnvAsBool("DEBUG", false),
			DefaultTZ:   getEnv("DEFAULT_TZ", "Asia/Shanghai"),
		},
		Database: DatabaseConfig{
			DSN:             getEnv("DB_DSN", ""),
			MaxIdleConns:    getEnvAsInt("DB_MAX_IDLE_CONNS", 10),
			MaxOpenConns:    getEnvAsInt("DB_MAX_OPEN_CONNS", 100),
			ConnMaxLifetime: time.Duration(getEnvAsInt("DB_CONN_MAX_LIFETIME", 3600)) * time.Second,
		},
		Redis: RedisConfig{
			URL:      getEnv("REDIS_URL", "redis://localhost:6379"),
			Password: getEnv("REDIS_PASSWORD", ""),
			DB:       getEnvAsInt("REDIS_DB", 0),
		},
		Lark: LarkConfig{
			AppID:     getEnv("FEISHU_APP_ID", ""),
			AppSecret: getEnv("FEISHU_APP_SECRET", ""),
		},
		Log: LogConfig{
			Level:  getEnv("LOG_LEVEL", "info"),
			Format: getEnv("LOG_FORMAT", "json"),
		},
		Redirect: RedirectConfig{
			DefaultTarget: getEnv("REDIRECT_DEFAULT_TARGET", "https://example.com/status/{SharingKey}"),
		},
		LegacyCrypto: LegacyConfig{
			Key:             getEnv("LEGACY_CRYPTO_KEY", "default-key-12345678"),
			IV:              getEnv("LEGACY_CRYPTO_IV", "default-iv-123456"),
			DefaultJumpLink: getEnv("LEGACY_DEFAULT_JUMP_LINK", "https://example.com"),
		},
	}

	// 设置日志级别
	if err := setupLogger(config); err != nil {
		return nil, err
	}

	logrus.Infof("Config loaded successfully: %+v", config)
	return config, nil
}

// loadEnv 加载环境变量文件
func loadEnv() error {
	appEnv := os.Getenv("APP_ENV")
	fileName := ".env"
	if appEnv != "" {
		fileName = ".env." + appEnv
	}

	if _, err := os.Stat(fileName); os.IsNotExist(err) {
		return nil // 文件不存在，使用系统环境变量
	}

	return godotenv.Load(fileName)
}

// getEnv 获取环境变量，如果不存在则返回默认值
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// getEnvAsInt 获取环境变量并转换为整数
func getEnvAsInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}

// getEnvAsBool 获取环境变量并转换为布尔值
func getEnvAsBool(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		if boolValue, err := strconv.ParseBool(value); err == nil {
			return boolValue
		}
	}
	return defaultValue
}

// setupLogger 设置日志配置
func setupLogger(cfg *Config) error {
	level, err := logrus.ParseLevel(cfg.Log.Level)
	if err != nil {
		level = logrus.InfoLevel
	}
	logrus.SetLevel(level)

	if cfg.Log.Format == "text" {
		logrus.SetFormatter(&logrus.TextFormatter{
			TimestampFormat: "2006-01-02 15:04:05",
			FullTimestamp:   true,
		})
	} else {
		logrus.SetFormatter(&logrus.JSONFormatter{
			TimestampFormat: "2006-01-02 15:04:05",
		})
	}

	return nil
}
