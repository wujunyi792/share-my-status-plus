package state

import (
	"context"
	"fmt"
	"share-my-status/domain/user"
	"share-my-status/infra/ws"
	"share-my-status/model"
	"time"

	common "share-my-status/api/model/share_my_status/common"
	state "share-my-status/api/model/share_my_status/state"

	"github.com/redis/go-redis/v9"
	"github.com/sirupsen/logrus"
	"gorm.io/datatypes"
	"gorm.io/gorm"
)

type StateService struct {
	db          *gorm.DB
	cache       *redis.Client
	wsService   *ws.DistributedWebSocketService
	userService *user.UserService
}

func NewStateService(db *gorm.DB, cache *redis.Client, wsService *ws.DistributedWebSocketService, userService *user.UserService) *StateService {
	return &StateService{
		db:          db,
		cache:       cache,
		wsService:   wsService,
		userService: userService,
	}
}

// SetWebSocketService 设置WebSocket服务
func (s *StateService) SetWebSocketService(wsService *ws.DistributedWebSocketService) {
	s.wsService = wsService
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
	snapshot := &common.StatusSnapshot{
		LastUpdateTs: event.Ts,
	}

	// 处理系统信息
	if event.System != nil {
		system := &common.System{}
		if event.System.BatteryPct != nil {
			system.BatteryPct = event.System.BatteryPct
		}
		if event.System.Charging != nil {
			system.Charging = event.System.Charging
		}
		if event.System.CpuPct != nil {
			system.CpuPct = event.System.CpuPct
		}
		if event.System.MemoryPct != nil {
			system.MemoryPct = event.System.MemoryPct
		}
		snapshot.System = system
	}

	// 处理音乐信息
	if event.Music != nil {
		music := &common.Music{}
		if event.Music.Title != nil {
			music.Title = event.Music.Title
		}
		if event.Music.Artist != nil {
			music.Artist = event.Music.Artist
		}
		if event.Music.Album != nil {
			music.Album = event.Music.Album
		}
		if event.Music.CoverHash != nil {
			music.CoverHash = event.Music.CoverHash
		}
		snapshot.Music = music
	}

	// 处理活动信息
	if event.Activity != nil {
		activity := &common.Activity{}
		if event.Activity.Label != "" {
			activity.Label = event.Activity.Label
		}
		snapshot.Activity = activity
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
func (s *StateService) updateCurrentState(ctx context.Context, openID string, snapshot *common.StatusSnapshot) error {
	var currentState model.CurrentState
	err := s.db.Where("open_id = ?", openID).First(&currentState).Error

	if err == gorm.ErrRecordNotFound {
		// 创建新的当前状态记录
		currentState = model.CurrentState{
			OpenID:   openID,
			Snapshot: datatypes.NewJSONType(*snapshot),
		}
		return s.db.Create(&currentState).Error
	} else if err != nil {
		return err
	}

	// 更新现有记录
	currentState.Snapshot = datatypes.NewJSONType(*snapshot)
	return s.db.Save(&currentState).Error
}

// saveHistory 保存历史记录
func (s *StateService) saveHistory(ctx context.Context, openID string, snapshot *common.StatusSnapshot) error {
	history := &model.StateHistory{
		OpenID:     openID,
		RecordedAt: time.Now(),
		Snapshot:   datatypes.NewJSONType(*snapshot),
	}

	return s.db.Create(history).Error
}

// broadcastStatusUpdate 广播状态更新
func (s *StateService) broadcastStatusUpdate(openID string, snapshot *common.StatusSnapshot) {
	if s.wsService != nil {
		s.wsService.BroadcastStatusUpdate(openID, snapshot)
	}
}

// QueryState 查询当前状态
func (s *StateService) QueryState(ctx context.Context, sharingKey string) (*state.QueryStateResponse, error) {
	// 获取用户
	user, err := s.userService.GetUserBySharingKey(sharingKey)
	if err != nil {
		return nil, fmt.Errorf("user not found: %w", err)
	}

	// 检查公开访问权限
	publicEnabled, err := s.userService.IsPublicEnabled(user.OpenID)
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

	// 获取快照数据
	snapshot := currentState.Snapshot.Data()

	message := "success"
	response := &state.QueryStateResponse{
		Base: &common.BaseResponse{
			Code:    0,
			Message: &message,
		},
		Snapshot: &snapshot,
	}

	return response, nil
}

// GetCurrentState 获取当前状态（内部使用）
func (s *StateService) GetCurrentState(ctx context.Context, openID string) (*common.StatusSnapshot, error) {
	var currentState model.CurrentState
	err := s.db.Where("open_id = ?", openID).First(&currentState).Error
	if err != nil {
		return nil, err
	}
	snapshot := currentState.Snapshot.Data()
	return &snapshot, nil
}
