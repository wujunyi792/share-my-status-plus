package service

import (
	"context"
	"fmt"
	"time"

	common "share-my-status/api/model/share_my_status/common"
	stats "share-my-status/api/model/share_my_status/stats"
	"share-my-status/internal/cache"
	"share-my-status/internal/database"
	"share-my-status/internal/model"

	"github.com/redis/go-redis/v9"
	"github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

// StatsService 统计服务
type StatsService struct {
	db    *gorm.DB
	cache *redis.Client
}

// NewStatsService 创建统计服务
func NewStatsService() *StatsService {
	return &StatsService{
		db:    database.GetDB(),
		cache: cache.GetClient(),
	}
}

// QueryStats 查询音乐统计
func (s *StatsService) QueryStats(ctx context.Context, openID string, req *stats.StatsQueryRequest) (*stats.StatsQueryResponse, error) {
	// 检查用户是否授权音乐统计
	userService := NewUserService()
	authorized, err := userService.IsMusicStatsAuthorized(openID)
	if err != nil {
		return nil, fmt.Errorf("failed to check music stats authorization: %w", err)
	}

	if !authorized {
		message := "Music stats not authorized"
		return &stats.StatsQueryResponse{
			Base: &common.BaseResponse{
				Code:    403,
				Message: &message,
			},
		}, nil
	}

	// 计算时间窗口
	window, err := s.calculateTimeWindow(req.Window.Type.String(), req.Window.Tz)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate time window: %w", err)
	}

	// 查询统计数据
	summary, topArtists, topTracks, err := s.getMusicStats(ctx, openID, window)
	if err != nil {
		return nil, fmt.Errorf("failed to get music stats: %w", err)
	}

	// 构建响应
	message := "success"
	response := &stats.StatsQueryResponse{
		Base: &common.BaseResponse{
			Code:    0,
			Message: &message,
		},
		Window:     req.Window,
		Summary:    summary,
		TopArtists: topArtists,
		TopTracks:  topTracks,
	}

	return response, nil
}

// calculateTimeWindow 计算时间窗口
func (s *StatsService) calculateTimeWindow(windowType string, tz string) (*TimeWindow, error) {
	if tz == "" {
		tz = "Asia/Shanghai" // 默认时区
	}

	loc, err := time.LoadLocation(tz)
	if err != nil {
		return nil, fmt.Errorf("invalid timezone: %w", err)
	}

	now := time.Now().In(loc)
	var startTime, endTime time.Time

	switch windowType {
	case "rolling_3d":
		startTime = now.AddDate(0, 0, -3)
		endTime = now
	case "rolling_7d":
		startTime = now.AddDate(0, 0, -7)
		endTime = now
	case "month_to_date":
		startTime = time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, loc)
		endTime = now
	case "year_to_date":
		startTime = time.Date(now.Year(), 1, 1, 0, 0, 0, 0, loc)
		endTime = now
	case "custom":
		// 自定义时间窗口，需要从请求中获取开始和结束时间
		// 这里简化处理，使用最近7天
		startTime = now.AddDate(0, 0, -7)
		endTime = now
	default:
		return nil, fmt.Errorf("unsupported window type: %s", windowType)
	}

	return &TimeWindow{
		StartTime: startTime,
		EndTime:   endTime,
		Timezone:  tz,
	}, nil
}

// TimeWindow 时间窗口
type TimeWindow struct {
	StartTime time.Time
	EndTime   time.Time
	Timezone  string
}

// getMusicStats 获取音乐统计
func (s *StatsService) getMusicStats(ctx context.Context, openID string, window *TimeWindow) (*common.StatsSummary, []*common.TopItem, []*common.TopItem, error) {
	// 先检查缓存
	cacheKey := fmt.Sprintf("stats:%s:%s:%d:%d", openID, window.Timezone, window.StartTime.Unix(), window.EndTime.Unix())
	cached, err := s.cache.Get(ctx, cacheKey).Result()
	if err == nil && cached != "" {
		// 这里应该反序列化缓存的数据，为了简化直接查询数据库
	}

	// 查询历史状态数据
	var histories []model.StateHistory
	err = s.db.WithContext(ctx).
		Where("open_id = ? AND recorded_at >= ? AND recorded_at <= ?",
			openID, window.StartTime, window.EndTime).
		Order("recorded_at ASC").
		Find(&histories).Error
	if err != nil {
		return nil, nil, nil, fmt.Errorf("failed to query state history: %w", err)
	}

	// 分析音乐数据
	summary, topArtists, topTracks := s.analyzeMusicData(histories)

	// 缓存结果（1小时）
	s.cache.Set(ctx, cacheKey, "cached", time.Hour)

	return summary, topArtists, topTracks, nil
}

// analyzeMusicData 分析音乐数据
func (s *StatsService) analyzeMusicData(histories []model.StateHistory) (*common.StatsSummary, []*common.TopItem, []*common.TopItem) {
	// 统计数据结构
	trackStats := make(map[string]*TrackStat)   // track -> stats
	artistStats := make(map[string]*ArtistStat) // artist -> stats
	albumStats := make(map[string]*AlbumStat)   // album -> stats

	var lastMusic *common.Music
	var lastUpdateTime time.Time
	var totalPlayTime int64 // 总播放时间（毫秒）

	for _, history := range histories {
		snapshot := history.Snapshot

		// 提取音乐信息
		musicData, ok := snapshot["music"].(map[string]interface{})
		if !ok {
			continue
		}

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

		// 计算播放时间
		if lastMusic != nil && !lastUpdateTime.IsZero() {
			// 如果音乐发生变化，记录上一首的播放时间
			if s.isMusicChanged(lastMusic, music) {
				playTime := history.RecordedAt.Sub(lastUpdateTime).Milliseconds()
				if playTime > 0 && playTime < 300000 { // 最多5分钟，避免异常数据
					s.updateTrackStats(trackStats, lastMusic, playTime)
					s.updateArtistStats(artistStats, lastMusic, playTime)
					s.updateAlbumStats(albumStats, lastMusic, playTime)
					totalPlayTime += playTime
				}
			}
		}

		lastMusic = music
		lastUpdateTime = history.RecordedAt
	}

	// 转换为API格式
	return s.convertToStatsResponse(trackStats, artistStats, albumStats, totalPlayTime)
}

// TrackStat 曲目统计
type TrackStat struct {
	Title     string
	Artist    string
	PlayTime  int64
	PlayCount int64
}

// ArtistStat 艺术家统计
type ArtistStat struct {
	Name       string
	PlayTime   int64
	TrackCount int64
}

// AlbumStat 专辑统计
type AlbumStat struct {
	Name       string
	Artist     string
	PlayTime   int64
	TrackCount int64
}

// isMusicChanged 检查音乐是否发生变化
func (s *StatsService) isMusicChanged(last, current *common.Music) bool {
	if last == nil || current == nil {
		return true
	}

	if last.Title == nil && current.Title == nil {
		return false
	}
	if last.Title == nil || current.Title == nil {
		return true
	}
	if *last.Title != *current.Title {
		return true
	}

	if last.Artist == nil && current.Artist == nil {
		return false
	}
	if last.Artist == nil || current.Artist == nil {
		return true
	}
	if *last.Artist != *current.Artist {
		return true
	}

	return false
}

// updateTrackStats 更新曲目统计
func (s *StatsService) updateTrackStats(trackStats map[string]*TrackStat, music *common.Music, playTime int64) {
	if music.Title == nil || music.Artist == nil {
		return
	}

	trackKey := *music.Title + " - " + *music.Artist
	if trackStats[trackKey] == nil {
		trackStats[trackKey] = &TrackStat{
			Title:     *music.Title,
			Artist:    *music.Artist,
			PlayTime:  0,
			PlayCount: 0,
		}
	}

	trackStats[trackKey].PlayTime += playTime
	trackStats[trackKey].PlayCount++
}

// updateArtistStats 更新艺术家统计
func (s *StatsService) updateArtistStats(artistStats map[string]*ArtistStat, music *common.Music, playTime int64) {
	if music.Artist == nil {
		return
	}

	artistKey := *music.Artist
	if artistStats[artistKey] == nil {
		artistStats[artistKey] = &ArtistStat{
			Name:       *music.Artist,
			PlayTime:   0,
			TrackCount: 0,
		}
	}

	artistStats[artistKey].PlayTime += playTime
	artistStats[artistKey].TrackCount++
}

// updateAlbumStats 更新专辑统计
func (s *StatsService) updateAlbumStats(albumStats map[string]*AlbumStat, music *common.Music, playTime int64) {
	if music.Album == nil || music.Artist == nil {
		return
	}

	albumKey := *music.Album + " - " + *music.Artist
	if albumStats[albumKey] == nil {
		albumStats[albumKey] = &AlbumStat{
			Name:       *music.Album,
			Artist:     *music.Artist,
			PlayTime:   0,
			TrackCount: 0,
		}
	}

	albumStats[albumKey].PlayTime += playTime
	albumStats[albumKey].TrackCount++
}

// convertToStatsResponse 转换为统计响应API格式
func (s *StatsService) convertToStatsResponse(trackStats map[string]*TrackStat, artistStats map[string]*ArtistStat, albumStats map[string]*AlbumStat, totalPlayTime int64) (*common.StatsSummary, []*common.TopItem, []*common.TopItem) {
	// 计算总播放次数
	totalPlays := int32(0)
	for _, stat := range trackStats {
		totalPlays += int32(stat.PlayCount)
	}

	// 创建统计摘要
	uniqueTracks := int32(len(trackStats))
	summary := &common.StatsSummary{
		Plays:        &totalPlays,
		UniqueTracks: &uniqueTracks,
	}

	// 转换艺术家统计为TopItem（按播放次数排序）
	var topArtists []*common.TopItem
	if len(artistStats) > 0 {
		topArtists = make([]*common.TopItem, 0, len(artistStats))
		for _, stat := range artistStats {
			topItem := &common.TopItem{
				Name:  stat.Name,
				Count: int32(stat.TrackCount),
			}
			topArtists = append(topArtists, topItem)
		}
	}

	// 转换曲目统计为TopItem（按播放次数排序）
	var topTracks []*common.TopItem
	if len(trackStats) > 0 {
		topTracks = make([]*common.TopItem, 0, len(trackStats))
		for _, stat := range trackStats {
			topItem := &common.TopItem{
				Name:  stat.Title + " - " + stat.Artist,
				Count: int32(stat.PlayCount),
			}
			topTracks = append(topTracks, topItem)
		}
	}

	return summary, topArtists, topTracks
}

// SaveMusicStats 保存音乐统计到数据库
func (s *StatsService) SaveMusicStats(ctx context.Context, openID string, windowType string, tz string, startTime, endTime time.Time, summary *common.StatsSummary, topArtists, topTracks []*common.TopItem) error {
	// 构建统计数据
	statsData := map[string]interface{}{
		"summary":    summary,
		"topArtists": topArtists,
		"topTracks":  topTracks,
	}

	// 创建音乐统计记录
	musicStats := &model.MusicStats{
		OpenID:     openID,
		WindowType: windowType,
		Tz:         tz,
		StartTime:  startTime,
		EndTime:    endTime,
		Stats:      statsData,
	}

	// 使用REPLACE INTO或UPSERT操作
	err := s.db.WithContext(ctx).Save(musicStats).Error
	if err != nil {
		return fmt.Errorf("failed to save music stats: %w", err)
	}

	logrus.Infof("Music stats saved for user %s, window %s", openID, windowType)
	return nil
}
