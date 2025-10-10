package scheduler

import (
	"context"
	"share-my-status/model"
	"time"

	"github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

// AnnualCleanupTask 年度清理任务，删除去年的所有历史记录
type AnnualCleanupTask struct {
	db *gorm.DB
}

// NewAnnualCleanupTask 创建年度清理任务
func NewAnnualCleanupTask(db *gorm.DB) *AnnualCleanupTask {
	return &AnnualCleanupTask{db: db}
}

// Name 返回任务名称
func (t *AnnualCleanupTask) Name() string {
	return "annual_cleanup_history"
}

// Schedule 返回任务调度表达式 - 每年1月1日凌晨2点执行
func (t *AnnualCleanupTask) Schedule() string {
	return "0 0 2 1 1 *" // 秒 分 时 日 月 周
}

// Execute 执行年度清理任务
func (t *AnnualCleanupTask) Execute(ctx context.Context) error {
	// 计算去年的时间范围
	now := time.Now()
	lastYear := now.Year() - 1
	lastYearStart := time.Date(lastYear, 1, 1, 0, 0, 0, 0, now.Location())
	lastYearEnd := time.Date(lastYear, 12, 31, 23, 59, 59, 999999999, now.Location())

	logrus.WithFields(logrus.Fields{
		"last_year":       lastYear,
		"last_year_start": lastYearStart,
		"last_year_end":   lastYearEnd,
	}).Info("Starting annual cleanup task")

	return t.db.Transaction(func(tx *gorm.DB) error {
		// 硬删除去年的所有StateHistory记录
		result := tx.Where("recorded_at >= ? AND recorded_at <= ?", lastYearStart, lastYearEnd).
			Delete(&model.StateHistory{})

		if result.Error != nil {
			logrus.WithError(result.Error).Error("Failed to delete last year's state history")
			return result.Error
		}

		deletedCount := result.RowsAffected

		logrus.WithFields(logrus.Fields{
			"deleted_history_count": deletedCount,
			"last_year":             lastYear,
		}).Info("Annual cleanup task completed successfully")

		return nil
	})
}
