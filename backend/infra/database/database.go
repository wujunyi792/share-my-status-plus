package database

import (
	"context"
	"share-my-status/infra/config"
	"share-my-status/model"

	"github.com/sirupsen/logrus"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// Init 初始化数据库连接
func Init(cfg *config.Config) (*gorm.DB, error) {
	dbCfg := cfg.Database

	// 配置GORM日志
	var logLevel logger.LogLevel
	if cfg.App.Debug {
		logLevel = logger.Info
	} else {
		logLevel = logger.Error
	}

	gormConfig := &gorm.Config{
		Logger: logger.Default.LogMode(logLevel),
	}

	// 连接数据库
	db, err := gorm.Open(mysql.Open(dbCfg.DSN), gormConfig)
	if err != nil {
		logrus.Errorf("Failed to connect to database: %v", err)
		return nil, err
	}

	// 获取底层sql.DB对象进行连接池配置
	sqlDB, err := db.DB()
	if err != nil {
		logrus.Errorf("Failed to get underlying sql.DB: %v", err)
		return nil, err
	}

	// 设置连接池参数
	sqlDB.SetMaxIdleConns(dbCfg.MaxIdleConns)
	sqlDB.SetMaxOpenConns(dbCfg.MaxOpenConns)
	sqlDB.SetConnMaxLifetime(dbCfg.ConnMaxLifetime)

	// 测试连接
	if err := sqlDB.PingContext(context.Background()); err != nil {
		logrus.Errorf("Failed to ping database: %v", err)
		return nil, err
	}

	// 创建表
	if err := model.CreateTables(db); err != nil {
		logrus.Errorf("Failed to create tables: %v", err)
		return nil, err
	}

	logrus.Info("Database connected and tables created successfully")
	return db, nil
}
