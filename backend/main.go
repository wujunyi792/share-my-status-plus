package main

import (
	"context"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"share-my-status/internal/config"
	"share-my-status/internal/lark"
	"share-my-status/internal/middleware"
	"share-my-status/internal/providers"
	"share-my-status/internal/scheduler"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
	hertzConfig "github.com/cloudwego/hertz/pkg/common/config"
	"github.com/hertz-contrib/cors"
	"github.com/sirupsen/logrus"
)

func main() {
	ctx := context.Background()

	// 使用Wire初始化所有依赖
	deps, err := providers.InitializeApp()
	if err != nil {
		logrus.Fatalf("Failed to initialize app dependencies: %v", err)
	}

	// 初始化飞书事件处理器
	eventHandler := lark.InitEventHandler()

	// 初始化飞书客户端（使用注入的Lark客户端）
	if err := lark.InitWithClient(eventHandler, deps.LarkClient); err != nil {
		logrus.Fatalf("Failed to initialize Lark client: %v", err)
	}

	// 启动飞书WebSocket连接
	if err := lark.StartWS(ctx); err != nil {
		logrus.Warnf("Failed to start Lark WebSocket: %v", err)
	}

	// 初始化WebSocket服务
	if err := deps.ServiceManager.InitWebSocketService(ctx); err != nil {
		logrus.Fatalf("Failed to initialize WebSocket service: %v", err)
	}

	// 初始化并启动定时任务调度器
	if config.GlobalConfig.Scheduler.Enabled {
		sched := scheduler.NewScheduler(deps.DB)
		sched.Start()

		// 启动HTTP服务器
		startHTTPServer(ctx, deps, sched)
	} else {
		// 启动HTTP服务器（不启用定时任务）
		startHTTPServer(ctx, deps, nil)
	}
}

func startHTTPServer(ctx context.Context, deps *providers.AppDependencies, sched *scheduler.Scheduler) {
	cfg := deps.Config.App

	// 创建服务器配置
	serverConfig := []hertzConfig.Option{
		server.WithHostPorts(":" + strconv.Itoa(cfg.Port)),
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

	// 注册路由（传递依赖）
	registerWithDeps(h, deps)

	// 健康检查端点
	h.GET("/healthz", func(ctx context.Context, c *app.RequestContext) {
		c.JSON(200, map[string]interface{}{
			"status":    "ok",
			"timestamp": time.Now().Unix(),
			"version":   cfg.Version,
		})
	})

	// 启动服务器
	go func() {
		logrus.Infof("Starting HTTP server on port %d", cfg.Port)
		h.Spin()
	}()

	// 等待中断信号
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logrus.Info("Shutting down server...")

	// 停止定时任务调度器
	if sched != nil {
		sched.Stop()
	}

	// 优雅关闭
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
