package service

import (
	"context"
	"sync"

	"github.com/sirupsen/logrus"
)

// ServiceManager 服务管理器
type ServiceManager struct {
	wsService *WebSocketService
	mu        sync.RWMutex
}

var (
	globalServiceManager *ServiceManager
	once                 sync.Once
)

// GetServiceManager 获取全局服务管理器
func GetServiceManager() *ServiceManager {
	once.Do(func() {
		globalServiceManager = &ServiceManager{}
	})
	return globalServiceManager
}

// InitWebSocketService 初始化WebSocket服务
func (sm *ServiceManager) InitWebSocketService(ctx context.Context) error {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	if sm.wsService != nil {
		return nil // 已经初始化
	}

	sm.wsService = NewWebSocketService()
	logrus.Info("WebSocket service initialized")
	return nil
}

// GetWebSocketService 获取WebSocket服务
func (sm *ServiceManager) GetWebSocketService() *WebSocketService {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	return sm.wsService
}

// SetWebSocketService 设置WebSocket服务（用于测试）
func (sm *ServiceManager) SetWebSocketService(ws *WebSocketService) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	sm.wsService = ws
}

// Shutdown 关闭所有服务
func (sm *ServiceManager) Shutdown(ctx context.Context) error {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	if sm.wsService != nil {
		// WebSocket服务没有显式的关闭方法，这里只是记录日志
		logrus.Info("WebSocket service shutdown")
	}

	return nil
}
