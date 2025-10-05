package service

import (
	"context"
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"time"

	"share-my-status/internal/cache"
	"share-my-status/internal/database"
	"share-my-status/internal/model"

	"github.com/redis/go-redis/v9"
	"github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

// CoverService 封面服务
type CoverService struct {
	db    *gorm.DB
	cache *redis.Client
}

// NewCoverService 创建封面服务
func NewCoverService() *CoverService {
	return &CoverService{
		db:    database.GetDB(),
		cache: cache.GetClient(),
	}
}

// CheckCoverExists 检查封面是否存在
func (s *CoverService) CheckCoverExists(ctx context.Context, coverHash string) (bool, error) {
	// 先检查缓存
	exists, err := s.cache.Exists(ctx, fmt.Sprintf("cover:%s", coverHash)).Result()
	if err == nil && exists > 0 {
		return true, nil
	}

	// 检查数据库
	var count int64
	err = s.db.WithContext(ctx).Model(&model.CoverAsset{}).Where("cover_hash = ?", coverHash).Count(&count).Error
	if err != nil {
		return false, fmt.Errorf("failed to check cover existence: %w", err)
	}

	existsInDB := count > 0

	// 缓存结果（5分钟）
	if existsInDB {
		s.cache.Set(ctx, fmt.Sprintf("cover:%s", coverHash), "1", 5*time.Minute)
	}

	return existsInDB, nil
}

// UploadCover 上传封面
func (s *CoverService) UploadCover(ctx context.Context, data []byte, contentType string) (string, error) {
	// 计算MD5哈希
	hash := md5.Sum(data)
	coverHash := hex.EncodeToString(hash[:])

	// 检查是否已存在
	exists, err := s.CheckCoverExists(ctx, coverHash)
	if err != nil {
		return "", fmt.Errorf("failed to check cover existence: %w", err)
	}

	if exists {
		// 更新最后访问时间
		s.cache.Set(ctx, fmt.Sprintf("cover:last_access:%s", coverHash), time.Now().Unix(), 24*time.Hour)
		return coverHash, nil
	}

	// 创建封面资产记录
	asset := map[string]interface{}{
		"contentType": contentType,
		"size":        len(data),
		"uploadTime":  time.Now().Unix(),
	}

	coverAsset := &model.CoverAsset{
		CoverHash: coverHash,
		Asset:     asset,
	}

	// 保存到数据库
	if err := s.db.WithContext(ctx).Create(coverAsset).Error; err != nil {
		return "", fmt.Errorf("failed to save cover asset: %w", err)
	}

	// 缓存封面存在信息
	s.cache.Set(ctx, fmt.Sprintf("cover:%s", coverHash), "1", 24*time.Hour)
	s.cache.Set(ctx, fmt.Sprintf("cover:last_access:%s", coverHash), time.Now().Unix(), 24*time.Hour)

	logrus.Infof("Cover uploaded successfully: %s (size: %d bytes)", coverHash, len(data))
	return coverHash, nil
}

// GetCover 获取封面信息
func (s *CoverService) GetCover(ctx context.Context, coverHash string) (*model.CoverAsset, error) {
	// 先检查缓存
	cacheKey := fmt.Sprintf("cover:asset:%s", coverHash)
	cached, err := s.cache.Get(ctx, cacheKey).Result()
	if err == nil && cached != "" {
		// 这里应该反序列化缓存的数据，为了简化直接查询数据库
	}

	// 查询数据库
	var coverAsset model.CoverAsset
	err = s.db.WithContext(ctx).Where("cover_hash = ?", coverHash).First(&coverAsset).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, fmt.Errorf("cover not found: %s", coverHash)
		}
		return nil, fmt.Errorf("failed to get cover: %w", err)
	}

	// 更新访问时间
	s.cache.Set(ctx, fmt.Sprintf("cover:last_access:%s", coverHash), time.Now().Unix(), 24*time.Hour)

	// 缓存资产信息（1小时）
	s.cache.Set(ctx, cacheKey, "cached", time.Hour)

	return &coverAsset, nil
}

// DeleteCover 删除封面
func (s *CoverService) DeleteCover(ctx context.Context, coverHash string) error {
	// 检查是否存在
	exists, err := s.CheckCoverExists(ctx, coverHash)
	if err != nil {
		return fmt.Errorf("failed to check cover existence: %w", err)
	}

	if !exists {
		return fmt.Errorf("cover not found: %s", coverHash)
	}

	// 从数据库删除
	if err := s.db.WithContext(ctx).Where("cover_hash = ?", coverHash).Delete(&model.CoverAsset{}).Error; err != nil {
		return fmt.Errorf("failed to delete cover: %w", err)
	}

	// 清除缓存
	s.cache.Del(ctx, fmt.Sprintf("cover:%s", coverHash))
	s.cache.Del(ctx, fmt.Sprintf("cover:asset:%s", coverHash))
	s.cache.Del(ctx, fmt.Sprintf("cover:last_access:%s", coverHash))

	logrus.Infof("Cover deleted successfully: %s", coverHash)
	return nil
}

// CleanupUnusedCovers 清理未使用的封面
func (s *CoverService) CleanupUnusedCovers(ctx context.Context, olderThan time.Duration) error {
	cutoffTime := time.Now().Add(-olderThan)

	// 查找超过指定时间未访问的封面
	var unusedCovers []model.CoverAsset
	err := s.db.WithContext(ctx).Find(&unusedCovers).Error
	if err != nil {
		return fmt.Errorf("failed to query unused covers: %w", err)
	}

	deletedCount := 0
	for _, cover := range unusedCovers {
		// 检查最后访问时间
		lastAccessStr, err := s.cache.Get(ctx, fmt.Sprintf("cover:last_access:%s", cover.CoverHash)).Result()
		if err != nil {
			// 缓存中没有访问记录，使用创建时间
			if cover.CreatedAt.Before(cutoffTime) {
				if err := s.DeleteCover(ctx, cover.CoverHash); err != nil {
					logrus.Errorf("Failed to delete unused cover %s: %v", cover.CoverHash, err)
				} else {
					deletedCount++
				}
			}
			continue
		}

		lastAccess, err := time.Parse(time.RFC3339, lastAccessStr)
		if err != nil {
			// 解析失败，使用创建时间
			if cover.CreatedAt.Before(cutoffTime) {
				if err := s.DeleteCover(ctx, cover.CoverHash); err != nil {
					logrus.Errorf("Failed to delete unused cover %s: %v", cover.CoverHash, err)
				} else {
					deletedCount++
				}
			}
			continue
		}

		// 检查最后访问时间是否超过阈值
		if lastAccess.Before(cutoffTime) {
			if err := s.DeleteCover(ctx, cover.CoverHash); err != nil {
				logrus.Errorf("Failed to delete unused cover %s: %v", cover.CoverHash, err)
			} else {
				deletedCount++
			}
		}
	}

	logrus.Infof("Cleaned up %d unused covers", deletedCount)
	return nil
}

// GetCoverStats 获取封面统计信息
func (s *CoverService) GetCoverStats(ctx context.Context) (map[string]interface{}, error) {
	// 总封面数量
	var totalCount int64
	err := s.db.WithContext(ctx).Model(&model.CoverAsset{}).Count(&totalCount).Error
	if err != nil {
		return nil, fmt.Errorf("failed to count total covers: %w", err)
	}

	// 缓存中的封面数量
	cacheKeys, err := s.cache.Keys(ctx, "cover:*").Result()
	if err != nil {
		logrus.Warnf("Failed to get cache keys: %v", err)
	}

	cachedCount := 0
	for _, key := range cacheKeys {
		if key != "" && key[:6] == "cover:" && len(key) > 6 {
			cachedCount++
		}
	}

	// 最近上传的封面数量（24小时内）
	recentTime := time.Now().Add(-24 * time.Hour)
	var recentCount int64
	err = s.db.WithContext(ctx).Model(&model.CoverAsset{}).Where("created_at > ?", recentTime).Count(&recentCount).Error
	if err != nil {
		return nil, fmt.Errorf("failed to count recent covers: %w", err)
	}

	stats := map[string]interface{}{
		"totalCovers":  totalCount,
		"cachedCovers": cachedCount,
		"recentCovers": recentCount,
		"timestamp":    time.Now().Unix(),
	}

	return stats, nil
}
