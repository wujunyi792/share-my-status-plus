package service

import (
	"context"
	"sync"

	"github.com/sirupsen/logrus"
)

// ServiceManager 服务管理器
type ServiceManager struct {
	distributedWSService *DistributedWebSocketService
	mu                   sync.RWMutex
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

	if sm.distributedWSService != nil {
		return nil // 已经初始化
	}

	sm.distributedWSService = NewDistributedWebSocketService()
	logrus.Info("Distributed WebSocket service initialized")
	return nil
}

// GetWebSocketService 获取WebSocket服务（兼容性方法）
func (sm *ServiceManager) GetWebSocketService() *DistributedWebSocketService {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	return sm.distributedWSService
}

// GetDistributedWebSocketService 获取分布式WebSocket服务
func (sm *ServiceManager) GetDistributedWebSocketService() *DistributedWebSocketService {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	return sm.distributedWSService
}

// SetWebSocketService 设置WebSocket服务（用于测试）
func (sm *ServiceManager) SetWebSocketService(ws *DistributedWebSocketService) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	sm.distributedWSService = ws
}

// Shutdown 关闭所有服务
func (sm *ServiceManager) Shutdown(ctx context.Context) error {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	if sm.distributedWSService != nil {
		sm.distributedWSService.Shutdown()
		logrus.Info("Distributed WebSocket service shutdown")
	}

	return nil
}
