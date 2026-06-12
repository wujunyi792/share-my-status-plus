package state

import (
	"context"
	"encoding/json"
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
			s.cache.Set(ctx, dedupKey, "1", 30*time.Second)
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

	// 单条原子 upsert：用 PostgreSQL 顶层 jsonb `||` 做模块级覆盖合并，等价于原来的
	// read → mergeSnapshots → write，但合并为一条语句完成。
	// 由于 StatusSnapshot 的 system/music/activity 都带 json omitempty，本次未上报的模块
	// 不会出现在 EXCLUDED 里、从而保留旧值；上报的模块整体覆盖；lastUpdateTs 总被更新。
	// 这消除了此前「两次 SELECT + 全行 Save」的开销，以及并发上报互相覆盖丢更新、
	// 并发首报主键冲突 500 的问题。RETURNING 拿到合并后的快照用于广播。
	snapshotJSON, err := json.Marshal(newSnapshot)
	if err != nil {
		return fmt.Errorf("failed to marshal snapshot: %w", err)
	}

	var row struct {
		Snapshot []byte `gorm:"column:snapshot"`
	}
	err = s.db.WithContext(ctx).Raw(
		`INSERT INTO current_state (user_id, snapshot, updated_at)
		 VALUES (?, ?::jsonb, now())
		 ON CONFLICT (user_id) DO UPDATE
		   SET snapshot = current_state.snapshot || EXCLUDED.snapshot, updated_at = now()
		 RETURNING snapshot`,
		userID, string(snapshotJSON),
	).Scan(&row).Error
	if err != nil {
		return fmt.Errorf("failed to upsert current state: %w", err)
	}

	// 合并结果（用于广播）；解析失败则退回本次上报的快照。
	mergedSnapshot := newSnapshot
	if len(row.Snapshot) > 0 {
		var merged common.StatusSnapshot
		if uErr := json.Unmarshal(row.Snapshot, &merged); uErr == nil {
			mergedSnapshot = &merged
		}
	}

	// 只有当事件包含音乐信息时才需要保存历史记录（用于音乐统计）
	if event.Music != nil {
		// 检查用户是否授权音乐统计，只有授权时才保存历史记录
		authorized, err := s.userService.IsMusicStatsAuthorized(userID)
		if err != nil {
			logrus.Errorf("Failed to check music stats authorization: %v", err)
			// 不返回错误，继续执行其他逻辑
		} else if authorized {
			// 保存历史记录（保存原始上报的快照）
			if err := s.saveHistory(ctx, userID, newSnapshot); err != nil {
				logrus.Errorf("Failed to save history: %v", err)
				// 不返回错误，因为当前状态已经更新
			}
		}
	}

	// 广播状态更新到WebSocket客户端（使用合并后的完整状态）
	if s.wsService != nil {
		go s.broadcastStatusUpdate(userID, mergedSnapshot)
	}

	return nil
}

// mergeSnapshots 合并两个状态快照（模块级整体覆盖）。
// 生产写路径已改用 PostgreSQL 的 jsonb `||` 在 SQL 侧原子完成同样的合并；本函数保留作为
// 该合并语义的可执行规范，并由 state_service_test.go 守护，确保两者行为一致。
func (s *StateService) mergeSnapshots(existing *common.StatusSnapshot, new *common.StatusSnapshot) *common.StatusSnapshot {
	merged := &common.StatusSnapshot{
		LastUpdateTs: new.LastUpdateTs, // 总是使用新的时间戳
	}
	if new.System != nil {
		merged.System = new.System
	} else {
		merged.System = existing.System
	}
	if new.Music != nil {
		merged.Music = new.Music
	} else {
		merged.Music = existing.Music
	}
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
