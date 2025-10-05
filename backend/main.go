package main

import (
	"context"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"share-my-status/internal/cache"
	"share-my-status/internal/config"
	"share-my-status/internal/database"
	"share-my-status/internal/lark"
	"share-my-status/internal/middleware"
	"share-my-status/internal/service"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
	hertzConfig "github.com/cloudwego/hertz/pkg/common/config"
	"github.com/hertz-contrib/cors"
	"github.com/sirupsen/logrus"
)

func main() {
	ctx := context.Background()

	// 初始化配置
	if err := config.Init(); err != nil {
		logrus.Fatalf("Failed to initialize config: %v", err)
	}

	// 初始化数据库
	if err := database.Init(ctx); err != nil {
		logrus.Fatalf("Failed to initialize database: %v", err)
	}
	defer database.Close()

	// 初始化Redis
	if err := cache.Init(ctx); err != nil {
		logrus.Fatalf("Failed to initialize Redis: %v", err)
	}
	defer cache.Close()

	// 初始化飞书事件处理器
	eventHandler := lark.InitEventHandler()

	// 初始化飞书客户端
	if err := lark.Init(eventHandler); err != nil {
		logrus.Fatalf("Failed to initialize Lark client: %v", err)
	}

	// 启动飞书WebSocket连接
	if err := lark.StartWS(ctx); err != nil {
		logrus.Warnf("Failed to start Lark WebSocket: %v", err)
	}

	// 初始化服务管理器
	serviceManager := service.GetServiceManager()
	if err := serviceManager.InitWebSocketService(ctx); err != nil {
		logrus.Fatalf("Failed to initialize WebSocket service: %v", err)
	}

	// 启动HTTP服务器
	startHTTPServer(ctx)
}

func startHTTPServer(ctx context.Context) {
	cfg := config.GlobalConfig.App

	// 创建服务器配置
	serverConfig := []hertzConfig.Option{
		server.WithHostPorts(":" + strconv.Itoa(cfg.Port)),
		server.WithMaxRequestBodySize(1024 * 1024 * 10), // 10MB
	}

	// 创建Hertz服务器
	h := server.Default(serverConfig...)

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

	// 优雅关闭
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := h.Shutdown(shutdownCtx); err != nil {
		logrus.Errorf("Server forced to shutdown: %v", err)
	}

	logrus.Info("Server exited")
}
