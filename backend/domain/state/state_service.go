package state

import (
	"context"
	"fmt"
	"share-my-status/domain/user"
	"share-my-status/infra/ws"
	"share-my-status/model"
	"share-my-status/pkg/dbutil"
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
func (s *StateService) BatchReport(ctx context.Context, userID uint64, events []*common.ReportEvent) (*state.BatchReportResponse, error) {
	accepted := int32(0)
	deduped := int32(0)

	// 处理每个事件
	for _, event := range events {
		// 检查幂等性
		if event.IdempotencyKey != nil && *event.IdempotencyKey != "" {
			dedupKey := fmt.Sprintf("dedup:%d:%s", userID, *event.IdempotencyKey)
			exists, err := s.cache.Exists(ctx, dedupKey).Result()
			if err == nil && exists > 0 {
				deduped++
				continue
			}
		}

		// 处理事件
		if err := s.processEvent(ctx, userID, event); err != nil {
			logrus.Errorf("Failed to process event: %v", err)
			continue
		}

		// 设置幂等键
		if event.IdempotencyKey != nil && *event.IdempotencyKey != "" {
			dedupKey := fmt.Sprintf("dedup:%d:%s", userID, *event.IdempotencyKey)
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
func (s *StateService) processEvent(ctx context.Context, userID uint64, event *common.ReportEvent) error {
	// 构建状态快照
	snapshot := &common.StatusSnapshot{
		LastUpdateTs: event.Ts,
	}

	// 使用辅助函数处理各种信息
	snapshot.System = event.System
	snapshot.Music = event.Music
	snapshot.Activity = event.Activity

	// 更新当前状态
	if err := s.updateCurrentState(ctx, userID, snapshot); err != nil {
		return fmt.Errorf("failed to update current state: %w", err)
	}

	// 保存历史记录
	if err := s.saveHistory(ctx, userID, snapshot); err != nil {
		logrus.Errorf("Failed to save history: %v", err)
		// 不返回错误，因为当前状态已经更新
	}

	// 广播状态更新到WebSocket客户端
	if s.wsService != nil {
		go s.broadcastStatusUpdate(userID, snapshot)
	}

	return nil
}

// updateCurrentState 更新当前状态，支持部分信息合并
func (s *StateService) updateCurrentState(ctx context.Context, userID uint64, snapshot *common.StatusSnapshot) error {
	var currentState model.CurrentState
	err := s.db.Where("user_id = ?", userID).First(&currentState).Error

	isNotFound, err := dbutil.HandleRecordNotFoundError(err)
	if isNotFound {
		// 创建新的当前状态记录
		currentState = model.CurrentState{
			UserID:   userID,
			Snapshot: datatypes.NewJSONType(*snapshot),
		}
		return s.db.Create(&currentState).Error
	} else if err != nil {
		return err
	}

	// 合并现有记录和新快照
	existingSnapshot := currentState.Snapshot.Data()
	mergedSnapshot := s.mergeSnapshots(&existingSnapshot, snapshot)
	
	// 更新现有记录
	currentState.Snapshot = datatypes.NewJSONType(*mergedSnapshot)
	return s.db.Save(&currentState).Error
}

// mergeSnapshots 合并两个状态快照，新快照的非空字段会覆盖旧快照的对应字段
func (s *StateService) mergeSnapshots(existing *common.StatusSnapshot, new *common.StatusSnapshot) *common.StatusSnapshot {
	// 创建合并后的快照，从现有快照开始
	merged := &common.StatusSnapshot{
		LastUpdateTs: new.LastUpdateTs, // 总是使用新的时间戳
	}

	// 合并系统信息
	if existing.System != nil {
		// 复制现有系统信息
		merged.System = &common.System{
			BatteryPct: existing.System.BatteryPct,
			Charging:   existing.System.Charging,
			CpuPct:     existing.System.CpuPct,
			MemoryPct:  existing.System.MemoryPct,
		}
	}
	if new.System != nil {
		if merged.System == nil {
			merged.System = &common.System{}
		}
		// 用新的非空字段覆盖
		if new.System.BatteryPct != nil {
			merged.System.BatteryPct = new.System.BatteryPct
		}
		if new.System.Charging != nil {
			merged.System.Charging = new.System.Charging
		}
		if new.System.CpuPct != nil {
			merged.System.CpuPct = new.System.CpuPct
		}
		if new.System.MemoryPct != nil {
			merged.System.MemoryPct = new.System.MemoryPct
		}
	}

	// 合并音乐信息
	if existing.Music != nil {
		// 复制现有音乐信息
		merged.Music = &common.Music{
			Title:     existing.Music.Title,
			Artist:    existing.Music.Artist,
			Album:     existing.Music.Album,
			CoverHash: existing.Music.CoverHash,
		}
	}
	if new.Music != nil {
		if merged.Music == nil {
			merged.Music = &common.Music{}
		}
		// 用新的非空字段覆盖
		if new.Music.Title != nil && *new.Music.Title != "" {
			merged.Music.Title = new.Music.Title
		}
		if new.Music.Artist != nil && *new.Music.Artist != "" {
			merged.Music.Artist = new.Music.Artist
		}
		if new.Music.Album != nil && *new.Music.Album != "" {
			merged.Music.Album = new.Music.Album
		}
		if new.Music.CoverHash != nil && *new.Music.CoverHash != "" {
			merged.Music.CoverHash = new.Music.CoverHash
		}
	}

	// 合并活动信息
	if existing.Activity != nil {
		// 复制现有活动信息
		merged.Activity = &common.Activity{
			Label: existing.Activity.Label,
		}
	}
	if new.Activity != nil {
		if merged.Activity == nil {
			merged.Activity = &common.Activity{}
		}
		// 用新的非空字段覆盖
		if new.Activity.Label != "" {
			merged.Activity.Label = new.Activity.Label
		}
	}

	return merged
}

// saveHistory 保存历史记录
func (s *StateService) saveHistory(ctx context.Context, userID uint64, snapshot *common.StatusSnapshot) error {
	history := &model.StateHistory{
		UserID:     userID,
		RecordedAt: time.Now(),
		Snapshot:   datatypes.NewJSONType(*snapshot),
	}

	return s.db.Create(history).Error
}

// broadcastStatusUpdate 广播状态更新
func (s *StateService) broadcastStatusUpdate(userID uint64, snapshot *common.StatusSnapshot) {
	if s.wsService != nil {
		s.wsService.BroadcastStatusUpdate(userID, snapshot)
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
	publicEnabled, err := s.userService.IsPublicEnabled(user.ID)
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

	// 使用统一的方法查询当前状态
	snapshot, err := dbutil.GetCurrentStateFromDB(ctx, s.db, user.ID)
	if err != nil {
		return nil, fmt.Errorf("failed to query current state: %w", err)
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

// GetCurrentState 获取当前状态（内部使用）
func (s *StateService) GetCurrentState(ctx context.Context, userID uint64) (*common.StatusSnapshot, error) {
	return dbutil.GetCurrentStateFromDB(ctx, s.db, userID)
}
