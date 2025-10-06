package main

import (
	"context"
	"os"
	"os/signal"
	"share-my-status/api/middleware"
	"share-my-status/infra"
	"strconv"
	"syscall"
	"time"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
	hertzConfig "github.com/cloudwego/hertz/pkg/common/config"
	"github.com/hertz-contrib/cors"
	"github.com/sirupsen/logrus"
)

func main() {
	ctx := context.Background()

	// 使用Wire初始化所有依赖
	deps, err := infra.InitializeApp()
	if err != nil {
		logrus.Fatalf("Failed to initialize app dependencies: %v", err)
	}
	infra.GlobalAppDependencies = deps

	// 启动飞书WebSocket连接
	go func() {
		if _err := deps.LarkWSClient.Start(ctx); _err != nil {
			logrus.Errorf("Failed to start Lark WebSocket client: %v", err)
		}
	}()

	// 启动HTTP服务器
	h := startHTTPServer(ctx, deps)

	// 等待中断信号并优雅退出
	waitForShutdown(h, deps)
}

// startHTTPServer 启动HTTP服务器并返回服务器实例
func startHTTPServer(ctx context.Context, deps *infra.AppDependencies) *server.Hertz {
	cfg := deps.Config

	// 创建服务器配置
	serverConfig := []hertzConfig.Option{
		server.WithHostPorts(":" + strconv.Itoa(cfg.App.Port)),
		server.WithMaxRequestBodySize(1024 * 1024 * 10), // 10MB
	}

	// 创建Hertz服务器
	h := server.Default(serverConfig...)

	// 启用WebSocket支持
	h.NoHijackConnPool = true

	// 配置CORS
	corsConfig := cors.DefaultConfig()
	corsConfig.AllowAllOrigins = true
	corsConfig.AllowHeaders = []string{"*"}
	corsHandler := cors.New(corsConfig)

	// 注册中间件
	h.Use(middleware.Logger())
	h.Use(middleware.Recovery())
	h.Use(middleware.CORS())
	h.Use(corsHandler)

	// 注册路由
	register(h)

	// 健康检查端点
	h.GET("/healthz", func(ctx context.Context, c *app.RequestContext) {
		c.JSON(200, map[string]interface{}{
			"status":    "ok",
			"timestamp": time.Now().Unix(),
			"version":   "1.0.0",
		})
	})

	// 启动服务器
	go func() {
		logrus.Infof("Starting HTTP server on port %d", cfg.App.Port)
		h.Spin()
	}()

	return h
}

// waitForShutdown 等待中断信号并优雅关闭服务器
func waitForShutdown(h *server.Hertz, deps *infra.AppDependencies) {
	// 等待中断信号
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logrus.Info("Shutting down server...")

	// 停止定时任务调度器
	deps.Scheduler.Stop()

	// 优雅关闭HTTP服务器
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := h.Shutdown(shutdownCtx); err != nil {
		logrus.Errorf("Server forced to shutdown: %v", err)
	}

	// 关闭依赖资源
	if deps.DB != nil {
		if sqlDB, err := deps.DB.DB(); err == nil {
			sqlDB.Close()
		}
	}
	if deps.RedisClient != nil {
		deps.RedisClient.Close()
	}

	logrus.Info("Server exited")
}
