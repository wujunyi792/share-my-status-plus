package lark

import (
	"share-my-status/infra/config"

	lark "github.com/larksuite/oapi-sdk-go/v3"
	larkcore "github.com/larksuite/oapi-sdk-go/v3/core"
	"github.com/larksuite/oapi-sdk-go/v3/event/dispatcher"
	larkws "github.com/larksuite/oapi-sdk-go/v3/ws"
)

// InitEventDispatcher 初始化飞书事件处理器
func InitEventDispatcher(cfg *config.Config, eventHandler *EventHandler) (*dispatcher.EventDispatcher, error) {
	return dispatcher.
			NewEventDispatcher(cfg.Lark.AppID, cfg.Lark.AppSecret).
			OnP2MessageReceiveV1(eventHandler.OnP2MessageReceiveV1).
			OnP2CardURLPreviewGet(eventHandler.OnP2CardURLPreviewGet),
		nil
}

// InitLarkClient 初始化飞书HTTP客户端
func InitLarkClient(cfg *config.Config) (*lark.Client, error) {
	return lark.NewClient(
		cfg.Lark.AppID,
		cfg.Lark.AppSecret,
		lark.WithLogLevel(larkcore.LogLevelError),
	), nil
}

// InitWsClient 初始化飞书WebSocket客户端
func InitWsClient(cfg *config.Config, eventHandler *dispatcher.EventDispatcher) (*larkws.Client, error) {
	return larkws.NewClient(
		cfg.Lark.AppID,
		cfg.Lark.AppSecret,
		larkws.WithEventHandler(eventHandler),
		larkws.WithLogLevel(larkcore.LogLevelError),
	), nil
}
