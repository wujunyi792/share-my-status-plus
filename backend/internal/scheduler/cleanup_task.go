package scheduler

import (
	"context"
	"time"

	"github.com/sirupsen/logrus"
	"gorm.io/gorm"
	"share-my-status/internal/config"
	"share-my-status/internal/model"
)

// CleanupTask 清理过期快照的定时任务
type CleanupTask struct {
	db *gorm.DB
}

// NewCleanupTask 创建清理任务
func NewCleanupTask(db *gorm.DB) *CleanupTask {
	return &CleanupTask{db: db}
}

// Name 返回任务名称
func (t *CleanupTask) Name() string {
	return "cleanup_expired_snapshots"
}

// Schedule 返回任务调度表达式
func (t *CleanupTask) Schedule() string {
	return config.GlobalConfig.Scheduler.CleanupCron
}

// Execute 执行清理任务
func (t *CleanupTask) Execute(ctx context.Context) error {
	// 计算过期时间
	retentionHours := config.GlobalConfig.Scheduler.SnapshotRetentionHours
	expiredTime := time.Now().Add(-time.Duration(retentionHours) * time.Hour)

	logrus.WithFields(logrus.Fields{
		"retention_hours": retentionHours,
		"expired_time":    expiredTime,
	}).Info("Starting cleanup task")

	return t.db.Transaction(func(tx *gorm.DB) error {
		// 1. 删除过期的StateHistory记录
		var expiredSnapshots []model.StateHistory
		if err := tx.Where("created_at < ?", expiredTime).Find(&expiredSnapshots).Error; err != nil {
			logrus.WithError(err).Error("Failed to find expired snapshots")
			return err
		}

		deletedSnapshots := int64(0)
		if len(expiredSnapshots) > 0 {
			result := tx.Where("created_at < ?", expiredTime).Delete(&model.StateHistory{})
			if result.Error != nil {
				logrus.WithError(result.Error).Error("Failed to delete expired snapshots")
				return result.Error
			}
			deletedSnapshots = result.RowsAffected
		}

		// 2. 删除不再被引用的CoverAsset记录
		var unusedAssets []model.CoverAsset

		// 查找所有被引用的cover_asset_id
		var referencedAssetIDs []uint

		// 从CurrentState表中获取被引用的asset ID
		if err := tx.Model(&model.CurrentState{}).
			Where("cover_asset_id IS NOT NULL").
			Pluck("cover_asset_id", &referencedAssetIDs).Error; err != nil {
			logrus.WithError(err).Error("Failed to get referenced asset IDs from current state")
			return err
		}

		// 从StateHistory表中获取被引用的asset ID
		var historyAssetIDs []uint
		if err := tx.Model(&model.StateHistory{}).
			Where("cover_asset_id IS NOT NULL").
			Pluck("cover_asset_id", &historyAssetIDs).Error; err != nil {
			logrus.WithError(err).Error("Failed to get referenced asset IDs from state history")
			return err
		}

		// 合并两个切片
		referencedAssetIDs = append(referencedAssetIDs, historyAssetIDs...)

		// 查找未被引用的资源
		query := tx.Model(&model.CoverAsset{})
		if len(referencedAssetIDs) > 0 {
			query = query.Where("id NOT IN (?)", referencedAssetIDs)
		}

		if err := query.Find(&unusedAssets).Error; err != nil {
			logrus.WithError(err).Error("Failed to find unused cover assets")
			return err
		}

		deletedAssets := int64(0)
		if len(unusedAssets) > 0 {
			result := tx.Where("id NOT IN (?)", referencedAssetIDs).Delete(&model.CoverAsset{})
			if result.Error != nil {
				logrus.WithError(result.Error).Error("Failed to delete unused cover assets")
				return result.Error
			}
			deletedAssets = result.RowsAffected
		}

		logrus.WithFields(logrus.Fields{
			"deleted_snapshots": deletedSnapshots,
			"deleted_assets":    deletedAssets,
		}).Info("Cleanup task completed successfully")

		return nil
	})
}
