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
	// 计算最新的时间戳 - 从各个数据结构中取最大值
	var lastUpdateTs int64
	if event.System != nil && event.System.Ts > lastUpdateTs {
		lastUpdateTs = event.System.Ts
	}
	if event.Music != nil && event.Music.Ts > lastUpdateTs {
		lastUpdateTs = event.Music.Ts
	}
	if event.Activity != nil && event.Activity.Ts > lastUpdateTs {
		lastUpdateTs = event.Activity.Ts
	}
	// 如果所有字段都为空，使用当前时间
	if lastUpdateTs == 0 {
		lastUpdateTs = time.Now().UnixMilli()
	}

	// 构建新的状态快照
	newSnapshot := &common.StatusSnapshot{
		LastUpdateTs: lastUpdateTs,
		System:       event.System,
		Music:        event.Music,
		Activity:     event.Activity,
	}

	// 获取现有状态并进行合并
	var currentState model.CurrentState
	err := s.db.Where("user_id = ?", userID).First(&currentState).Error

	var mergedSnapshot *common.StatusSnapshot
	isNotFound, err := dbutil.HandleRecordNotFoundError(err)
	if isNotFound {
		// 如果是首次创建，直接使用新快照
		mergedSnapshot = newSnapshot
	} else if err != nil {
		return fmt.Errorf("failed to get current state: %w", err)
	} else {
		// 合并现有状态和新快照
		existingSnapshot := currentState.Snapshot.Data()
		mergedSnapshot = s.mergeSnapshots(&existingSnapshot, newSnapshot)
	}

	// 更新当前状态（保存合并后的完整状态）
	if err := s.updateCurrentState(ctx, userID, mergedSnapshot); err != nil {
		return fmt.Errorf("failed to update current state: %w", err)
	}

	// 保存历史记录（保存原始上报的快照）
	if err := s.saveHistory(ctx, userID, newSnapshot); err != nil {
		logrus.Errorf("Failed to save history: %v", err)
		// 不返回错误，因为当前状态已经更新
	}

	// 广播状态更新到WebSocket客户端（使用合并后的完整状态）
	if s.wsService != nil {
		go s.broadcastStatusUpdate(userID, mergedSnapshot)
	}

	return nil
}

// updateCurrentState 更新当前状态
// 直接保存传入的完整快照，不做合并处理（合并逻辑在调用方完成）
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

	// 更新现有记录
	currentState.Snapshot = datatypes.NewJSONType(*snapshot)
	return s.db.Save(&currentState).Error
}

// mergeSnapshots 合并两个状态快照
// 新的合并策略：对每次上报的音乐、系统和活动信息分别作为一个整体做覆盖
// 如果新快照中某个模块不为空，则整体替换旧快照中的对应模块
func (s *StateService) mergeSnapshots(existing *common.StatusSnapshot, new *common.StatusSnapshot) *common.StatusSnapshot {
	// 创建合并后的快照，从现有快照开始
	merged := &common.StatusSnapshot{
		LastUpdateTs: new.LastUpdateTs, // 总是使用新的时间戳
	}

	// 系统信息：如果新快照中有 System，整体覆盖；否则保留旧的
	if new.System != nil {
		merged.System = new.System
	} else {
		merged.System = existing.System
	}

	// 音乐信息：如果新快照中有 Music，整体覆盖；否则保留旧的
	if new.Music != nil {
		merged.Music = new.Music
	} else {
		merged.Music = existing.Music
	}

	// 活动信息：如果新快照中有 Activity，整体覆盖；否则保留旧的
	if new.Activity != nil {
		merged.Activity = new.Activity
	} else {
		merged.Activity = existing.Activity
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
