package lark

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"time"

	"share-my-status/internal/config"

	lark "github.com/larksuite/oapi-sdk-go/v3"
	larkcore "github.com/larksuite/oapi-sdk-go/v3/core"
	"github.com/larksuite/oapi-sdk-go/v3/event/dispatcher"
	larkws "github.com/larksuite/oapi-sdk-go/v3/ws"
	"github.com/sirupsen/logrus"
)

var (
	larkClient *lark.Client
	larkWS     *larkws.Client
)

// InitEventHandler 初始化飞书事件处理器
func InitEventHandler() *dispatcher.EventDispatcher {
	return dispatcher.NewEventDispatcher(
		config.GlobalConfig.Lark.AppID,
		config.GlobalConfig.Lark.AppSecret,
	).OnP2MessageReceiveV1(OnP2MessageReceiveV1).OnP2CardURLPreviewGet(OnP2CardURLPreviewGet)
}

// Init 初始化飞书客户端
func Init(eventHandler *dispatcher.EventDispatcher) error {
	cfg := config.GlobalConfig.Lark

	if cfg.AppID == "" || cfg.AppSecret == "" {
		logrus.Warn("Lark AppID or AppSecret not configured, skipping Lark initialization")
		return nil
	}

	// 创建HTTP客户端
	larkClient = lark.NewClient(
		cfg.AppID,
		cfg.AppSecret,
		lark.WithLogLevel(larkcore.LogLevelError),
	)

	// 创建WebSocket客户端
	if eventHandler != nil {
		larkWS = larkws.NewClient(
			cfg.AppID,
			cfg.AppSecret,
			larkws.WithEventHandler(eventHandler),
			larkws.WithLogLevel(larkcore.LogLevelError),
		)
	}

	logrus.Info("Lark client initialized successfully")
	return nil
}

// GetClient 获取飞书HTTP客户端
func GetClient() *lark.Client {
	return larkClient
}

// GetWSClient 获取飞书WebSocket客户端
func GetWSClient() *larkws.Client {
	return larkWS
}

// StartWS 启动WebSocket连接
func StartWS(ctx context.Context) error {
	if larkWS == nil {
		return fmt.Errorf("lark WebSocket client not initialized")
	}

	go func() {
		if err := larkWS.Start(ctx); err != nil {
			logrus.Errorf("Failed to start Lark WebSocket: %v", err)
		}
	}()

	logrus.Info("Lark WebSocket started successfully")
	return nil
}

// StopWS 停止WebSocket连接
func StopWS() error {
	if larkWS != nil {
		// WebSocket客户端没有Stop方法，这里只是记录日志
		logrus.Info("Lark WebSocket stopped")
	}
	return nil
}

// VerifySignature 验证飞书请求签名
func VerifySignature(timestamp, nonce, signature, body string) bool {
	// 构建待签名字符串
	toSign := timestamp + nonce + body

	// 计算签名
	h := sha256.New()
	h.Write([]byte(toSign))
	calculatedSignature := hex.EncodeToString(h.Sum(nil))

	return calculatedSignature == signature
}

// GeneratePreviewURL 生成预览URL
func GeneratePreviewURL(sharingKey, template, redirect string) string {
	baseURL := "https://status.example.com" // 这里应该从配置中获取
	url := fmt.Sprintf("%s/s/%s", baseURL, sharingKey)

	params := make([]string, 0)
	if template != "" {
		params = append(params, fmt.Sprintf("m=%s", template))
	}
	if redirect != "" {
		params = append(params, fmt.Sprintf("r=%s", redirect))
	}

	if len(params) > 0 {
		url += "?" + params[0]
		for i := 1; i < len(params); i++ {
			url += "&" + params[i]
		}
	}

	return url
}

// CreatePreviewResponse 创建链接预览响应
func CreatePreviewResponse(title, description, imageURL string) map[string]interface{} {
	return map[string]interface{}{
		"title":       title,
		"description": description,
		"image_url":   imageURL,
		"timestamp":   time.Now().Unix(),
	}
}
