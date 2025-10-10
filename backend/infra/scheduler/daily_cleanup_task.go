package scheduler

import (
	"context"
	"share-my-status/model"
	"time"

	"github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

// DailyCleanupTask 日常清理任务，删除一天没有更新的CurrentState记录
type DailyCleanupTask struct {
	db *gorm.DB
}

// NewDailyCleanupTask 创建日常清理任务
func NewDailyCleanupTask(db *gorm.DB) *DailyCleanupTask {
	return &DailyCleanupTask{db: db}
}

// Name 返回任务名称
func (t *DailyCleanupTask) Name() string {
	return "daily_cleanup_current_state"
}

// Schedule 返回任务调度表达式 - 每天凌晨3点执行
func (t *DailyCleanupTask) Schedule() string {
	return "0 0 3 * * *" // 秒 分 时 日 月 周
}

// Execute 执行日常清理任务
func (t *DailyCleanupTask) Execute(ctx context.Context) error {
	// 计算一天前的时间
	oneDayAgo := time.Now().Add(-24 * time.Hour)

	logrus.WithFields(logrus.Fields{
		"cutoff_time": oneDayAgo,
	}).Info("Starting daily cleanup task for current states")

	return t.db.Transaction(func(tx *gorm.DB) error {
		// 硬删除一天没有更新的CurrentState记录
		result := tx.Where("updated_at < ?", oneDayAgo).
			Delete(&model.CurrentState{})

		if result.Error != nil {
			logrus.WithError(result.Error).Error("Failed to delete stale current states")
			return result.Error
		}

		deletedCount := result.RowsAffected

		logrus.WithFields(logrus.Fields{
			"deleted_current_state_count": deletedCount,
			"cutoff_time":                 oneDayAgo,
		}).Info("Daily cleanup task completed successfully")

		return nil
	})
}
