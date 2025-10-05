package database

import (
	"context"

	"share-my-status/internal/config"
	"share-my-status/internal/model"

	"github.com/sirupsen/logrus"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

// Init 初始化数据库连接
func Init(ctx context.Context) error {
	cfg := config.GlobalConfig.Database

	// 配置GORM日志
	var logLevel logger.LogLevel
	if config.GlobalConfig.App.Debug {
		logLevel = logger.Info
	} else {
		logLevel = logger.Error
	}

	gormConfig := &gorm.Config{
		Logger: logger.Default.LogMode(logLevel),
	}

	// 连接数据库
	db, err := gorm.Open(mysql.Open(cfg.DSN), gormConfig)
	if err != nil {
		logrus.Errorf("Failed to connect to database: %v", err)
		return err
	}

	// 获取底层sql.DB对象进行连接池配置
	sqlDB, err := db.DB()
	if err != nil {
		logrus.Errorf("Failed to get underlying sql.DB: %v", err)
		return err
	}

	// 设置连接池参数
	sqlDB.SetMaxIdleConns(cfg.MaxIdleConns)
	sqlDB.SetMaxOpenConns(cfg.MaxOpenConns)
	sqlDB.SetConnMaxLifetime(cfg.ConnMaxLifetime)

	// 测试连接
	if err := sqlDB.PingContext(ctx); err != nil {
		logrus.Errorf("Failed to ping database: %v", err)
		return err
	}

	DB = db

	// 创建表
	if err := model.CreateTables(DB); err != nil {
		logrus.Errorf("Failed to create tables: %v", err)
		return err
	}

	logrus.Info("Database connected and tables created successfully")
	return nil
}

// Close 关闭数据库连接
func Close() error {
	if DB != nil {
		sqlDB, err := DB.DB()
		if err != nil {
			return err
		}
		return sqlDB.Close()
	}
	return nil
}

// GetDB 获取数据库实例
func GetDB() *gorm.DB {
	return DB
}
