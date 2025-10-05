package service

import (
	"context"
	"fmt"
	"time"

	common "share-my-status/api/model/share_my_status/common"
	state "share-my-status/api/model/share_my_status/state"
	"share-my-status/internal/cache"
	"share-my-status/internal/database"
	"share-my-status/internal/model"

	"github.com/redis/go-redis/v9"
	"github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

type StateService struct {
	db        *gorm.DB
	cache     *redis.Client
	wsService *WebSocketService
}

func NewStateService() *StateService {
	return &StateService{
		db:        database.GetDB(),
		cache:     cache.GetClient(),
		wsService: nil, // 将通过SetWebSocketService设置
	}
}

// SetWebSocketService 设置WebSocket服务
func (s *StateService) SetWebSocketService(wsService *WebSocketService) {
	s.wsService = wsService
}

// InitWebSocketService 初始化WebSocket服务
func (s *StateService) InitWebSocketService() {
	serviceManager := GetServiceManager()
	s.wsService = serviceManager.GetWebSocketService()
}

// BatchReport 批量上报状态
func (s *StateService) BatchReport(ctx context.Context, openID string, events []*common.ReportEvent) (*state.BatchReportResponse, error) {
	accepted := int32(0)
	deduped := int32(0)

	// 处理每个事件
	for _, event := range events {
		// 检查幂等性
		if event.IdempotencyKey != nil && *event.IdempotencyKey != "" {
			dedupKey := fmt.Sprintf("dedup:%s:%s", openID, *event.IdempotencyKey)
			exists, err := s.cache.Exists(ctx, dedupKey).Result()
			if err == nil && exists > 0 {
				deduped++
				continue
			}
		}

		// 处理事件
		if err := s.processEvent(ctx, openID, event); err != nil {
			logrus.Errorf("Failed to process event: %v", err)
			continue
		}

		// 设置幂等键
		if event.IdempotencyKey != nil && *event.IdempotencyKey != "" {
			dedupKey := fmt.Sprintf("dedup:%s:%s", openID, *event.IdempotencyKey)
			s.cache.Set(ctx, dedupKey, "1", 24*time.Hour)
		}

		accepted++
	}

	// 构建响应
	message := "success"
	response := &state.BatchReportResponse{
		Base: &common.BaseResponse{
			Code:    0,
			Message: &message,
		},
		Accepted: &accepted,
		Deduped:  &deduped,
	}

	return response, nil
}

// processEvent 处理单个事件
func (s *StateService) processEvent(ctx context.Context, openID string, event *common.ReportEvent) error {
	// 构建状态快照
	snapshot := map[string]interface{}{
		"lastUpdateTs": event.Ts,
	}

	// 处理系统信息
	if event.System != nil {
		systemData := make(map[string]interface{})
		if event.System.BatteryPct != nil {
			systemData["batteryPct"] = *event.System.BatteryPct
		}
		if event.System.Charging != nil {
			systemData["charging"] = *event.System.Charging
		}
		if event.System.CpuPct != nil {
			systemData["cpuPct"] = *event.System.CpuPct
		}
		if event.System.MemoryPct != nil {
			systemData["memoryPct"] = *event.System.MemoryPct
		}
		snapshot["system"] = systemData
	}

	// 处理音乐信息
	if event.Music != nil {
		musicData := make(map[string]interface{})
		if event.Music.Title != nil {
			musicData["title"] = *event.Music.Title
		}
		if event.Music.Artist != nil {
			musicData["artist"] = *event.Music.Artist
		}
		if event.Music.Album != nil {
			musicData["album"] = *event.Music.Album
		}
		if event.Music.CoverHash != nil {
			musicData["coverHash"] = *event.Music.CoverHash
		}
		snapshot["music"] = musicData
	}

	// 处理活动信息
	if event.Activity != nil {
		activityData := make(map[string]interface{})
		activityData["label"] = event.Activity.Label
		snapshot["activity"] = activityData
	}

	// 更新当前状态
	if err := s.updateCurrentState(ctx, openID, snapshot); err != nil {
		return fmt.Errorf("failed to update current state: %w", err)
	}

	// 保存历史记录
	if err := s.saveHistory(ctx, openID, snapshot); err != nil {
		logrus.Errorf("Failed to save history: %v", err)
		// 不返回错误，因为当前状态已经更新
	}

	// 广播状态更新到WebSocket客户端
	if s.wsService != nil {
		go s.broadcastStatusUpdate(openID, snapshot)
	}

	return nil
}

// updateCurrentState 更新当前状态
func (s *StateService) updateCurrentState(ctx context.Context, openID string, snapshot map[string]interface{}) error {
	var currentState model.CurrentState
	err := s.db.Where("open_id = ?", openID).First(&currentState).Error

	if err == gorm.ErrRecordNotFound {
		// 创建新的当前状态记录
		currentState = model.CurrentState{
			OpenID:   openID,
			Snapshot: snapshot,
		}
		return s.db.Create(&currentState).Error
	} else if err != nil {
		return err
	}

	// 更新现有记录
	currentState.Snapshot = snapshot
	return s.db.Save(&currentState).Error
}

// saveHistory 保存历史记录
func (s *StateService) saveHistory(ctx context.Context, openID string, snapshot map[string]interface{}) error {
	history := &model.StateHistory{
		OpenID:     openID,
		RecordedAt: time.Now(),
		Snapshot:   snapshot,
	}

	return s.db.Create(history).Error
}

// broadcastStatusUpdate 广播状态更新
func (s *StateService) broadcastStatusUpdate(openID string, snapshot map[string]interface{}) {
	// 转换为API格式
	apiSnapshot, err := s.convertToStatusSnapshot(snapshot)
	if err != nil {
		logrus.Errorf("Failed to convert snapshot for broadcast: %v", err)
		return
	}

	// 广播到WebSocket客户端
	s.wsService.BroadcastStatusUpdate(openID, apiSnapshot)
}

// QueryState 查询当前状态
func (s *StateService) QueryState(ctx context.Context, sharingKey string) (*state.QueryStateResponse, error) {
	// 获取用户
	userService := NewUserService()
	user, err := userService.GetUserBySharingKey(sharingKey)
	if err != nil {
		return nil, fmt.Errorf("user not found: %w", err)
	}

	// 检查公开访问权限
	publicEnabled, err := userService.IsPublicEnabled(user.OpenID)
	if err != nil {
		return nil, fmt.Errorf("failed to check public access: %w", err)
	}

	if !publicEnabled {
		message := "Public access is disabled"
		return &state.QueryStateResponse{
			Base: &common.BaseResponse{
				Code:    403,
				Message: &message,
			},
		}, nil
	}

	// 查询当前状态
	var currentState model.CurrentState
	err = s.db.Where("open_id = ?", user.OpenID).First(&currentState).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			message := "success"
			return &state.QueryStateResponse{
				Base: &common.BaseResponse{
					Code:    0,
					Message: &message,
				},
			}, nil
		}
		return nil, fmt.Errorf("failed to query current state: %w", err)
	}

	// 转换为API格式
	snapshot, err := s.convertToStatusSnapshot(currentState.Snapshot)
	if err != nil {
		return nil, fmt.Errorf("failed to convert snapshot: %w", err)
	}

	message := "success"
	response := &state.QueryStateResponse{
		Base: &common.BaseResponse{
			Code:    0,
			Message: &message,
		},
		Snapshot: snapshot,
	}

	return response, nil
}

// convertToStatusSnapshot 转换为状态快照格式
func (s *StateService) convertToStatusSnapshot(snapshotData map[string]interface{}) (*common.StatusSnapshot, error) {
	snapshot := &common.StatusSnapshot{}

	// 转换最后更新时间
	if lastUpdateTs, ok := snapshotData["lastUpdateTs"].(float64); ok {
		snapshot.LastUpdateTs = int64(lastUpdateTs)
	}

	// 转换系统信息
	if systemData, ok := snapshotData["system"].(map[string]interface{}); ok {
		system := &common.System{}

		if batteryPct, ok := systemData["batteryPct"].(float64); ok {
			system.BatteryPct = &batteryPct
		}
		if charging, ok := systemData["charging"].(bool); ok {
			system.Charging = &charging
		}
		if cpuPct, ok := systemData["cpuPct"].(float64); ok {
			system.CpuPct = &cpuPct
		}
		if memoryPct, ok := systemData["memoryPct"].(float64); ok {
			system.MemoryPct = &memoryPct
		}

		snapshot.System = system
	}

	// 转换音乐信息
	if musicData, ok := snapshotData["music"].(map[string]interface{}); ok {
		music := &common.Music{}

		if title, ok := musicData["title"].(string); ok {
			music.Title = &title
		}
		if artist, ok := musicData["artist"].(string); ok {
			music.Artist = &artist
		}
		if album, ok := musicData["album"].(string); ok {
			music.Album = &album
		}
		if coverHash, ok := musicData["coverHash"].(string); ok {
			music.CoverHash = &coverHash
		}

		snapshot.Music = music
	}

	// 转换活动信息
	if activityData, ok := snapshotData["activity"].(map[string]interface{}); ok {
		if label, ok := activityData["label"].(string); ok {
			activity := &common.Activity{
				Label: label,
			}
			snapshot.Activity = activity
		}
	}

	return snapshot, nil
}

// GetCurrentState 获取当前状态（内部使用）
func (s *StateService) GetCurrentState(ctx context.Context, openID string) (map[string]interface{}, error) {
	var currentState model.CurrentState
	err := s.db.Where("open_id = ?", openID).First(&currentState).Error
	if err != nil {
		return nil, err
	}
	return currentState.Snapshot, nil
}
