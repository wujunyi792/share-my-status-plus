package dbutil

import (
	"context"
	"time"

	common "share-my-status/api/model/share_my_status/common"
	"share-my-status/model"

	"gorm.io/gorm"
)

// GetCurrentStateFromDB 从数据库获取用户当前状态的通用方法
// 这个方法可以被多个服务复用，避免重复代码
func GetCurrentStateFromDB(ctx context.Context, db *gorm.DB, userID uint64) (*common.StatusSnapshot, error) {
	var currentState model.CurrentState
	err := db.WithContext(ctx).Where("user_id = ?", userID).First(&currentState).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			// 返回空快照而不是nil，保持一致性
			return &common.StatusSnapshot{
				LastUpdateTs: time.Now().UnixMilli(),
			}, nil
		}
		return nil, err
	}

	// 提取快照数据
	snapshot := currentState.Snapshot.Data()
	return &snapshot, nil
}

// HandleRecordNotFoundError 统一处理记录不存在的错误
func HandleRecordNotFoundError(err error) (bool, error) {
	if err == gorm.ErrRecordNotFound {
		return true, nil // 表示记录不存在但不是错误
	}
	return false, err
}