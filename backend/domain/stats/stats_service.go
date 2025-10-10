package stats

import (
	"context"
	"encoding/json"
	"fmt"
	"share-my-status/domain/user"
	"share-my-status/model"
	"share-my-status/pkg/ptr"
	"time"

	common "share-my-status/api/model/share_my_status/common"
	stats "share-my-status/api/model/share_my_status/stats"

	"github.com/bytedance/gg/gslice"
	"github.com/jinzhu/now"
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
func NewStatsService(db *gorm.DB, cache *redis.Client) *StatsService {
	return &StatsService{
		db:    db,
		cache: cache,
	}
}

// QueryStats 查询音乐统计
func (s *StatsService) QueryStats(ctx context.Context, userID uint64, req *stats.StatsQueryRequest) (*stats.StatsQueryResponse, error) {
	// 通过userID获取用户信息
	userService := user.NewUserService(s.db, s.cache)

	// 检查用户是否授权音乐统计
	authorized, err := userService.IsMusicStatsAuthorized(userID)
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
	window, err := s.calculateTimeWindow(req)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate time window: %w", err)
	}

	req.Window.FromTs = ptr.Of(window.StartTime.UnixMilli())
	req.Window.ToTs = ptr.Of(window.EndTime.UnixMilli())

	// 获取topN参数，默认为10
	topN := req.TopN
	if topN <= 0 {
		topN = 20
	}

	// 查询统计数据
	summary, topArtists, topTracks, topAlbums, cached, err := s.getMusicStats(ctx, userID, window, topN)
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
		TopAlbums:  topAlbums,
		Cached:     cached,
	}

	return response, nil
}

// calculateTimeWindow 计算时间窗口
func (s *StatsService) calculateTimeWindow(req *stats.StatsQueryRequest) (*TimeWindow, error) {
	tz := req.Window.Tz
	if tz == "" {
		tz = "Asia/Shanghai" // 默认时区
	}
	loc, err := time.LoadLocation(tz)
	if err != nil {
		return nil, fmt.Errorf("invalid timezone: %w", err)
	}

	// 使用jinzhu/now库配置时区
	nowConfig := &now.Config{
		TimeLocation: loc,
	}
	currentTime := nowConfig.With(time.Now().In(loc))

	var startTime, endTime time.Time

	switch req.Window.Type {
	case common.WindowType_ROLLING_3D:
		// 对齐到整点：结束时间对齐到当前小时，开始时间往前推3天
		endTime = currentTime.BeginningOfHour()
		startTime = nowConfig.With(endTime.AddDate(0, 0, -3)).BeginningOfHour()
	case common.WindowType_ROLLING_7D:
		// 对齐到整点：结束时间对齐到当前小时，开始时间往前推7天
		endTime = currentTime.BeginningOfHour()
		startTime = nowConfig.With(endTime.AddDate(0, 0, -7)).BeginningOfHour()
	case common.WindowType_MONTH_TO_DATE:
		// 月初到当前小时
		startTime = currentTime.BeginningOfMonth()
		endTime = currentTime.BeginningOfHour()
	case common.WindowType_YEAR_TO_DATE:
		// 年初到当前小时
		startTime = currentTime.BeginningOfYear()
		endTime = currentTime.BeginningOfHour()
	case common.WindowType_CUSTOM:
		// 自定义时间窗口，从请求中获取开始和结束时间
		if req.Window.Custom == nil {
			return nil, fmt.Errorf("custom window parameters are required")
		}

		// 将毫秒时间戳转换为time.Time并对齐到整点
		startTimeRaw := time.Unix(req.Window.Custom.FromTs/1000, (req.Window.Custom.FromTs%1000)*1000000).In(loc)
		endTimeRaw := time.Unix(req.Window.Custom.ToTs/1000, (req.Window.Custom.ToTs%1000)*1000000).In(loc)

		startTime = nowConfig.With(startTimeRaw).BeginningOfHour()
		endTime = nowConfig.With(endTimeRaw).BeginningOfHour()

		// 验证时间范围
		if startTime.After(endTime) {
			return nil, fmt.Errorf("start time cannot be after end time")
		}

		// 限制时间范围（最多1年）
		if endTime.Sub(startTime) > 365*24*time.Hour {
			return nil, fmt.Errorf("time window cannot exceed 1 year")
		}
	default:
		return nil, fmt.Errorf("unsupported window type: %s", req.Window.Type.String())
	}

	return &TimeWindow{
		StartTime: startTime,
		EndTime:   endTime,
		Timezone:  tz,
	}, nil
}

// alignToHour 将时间对齐到整点
// TimeWindow 时间窗口
type TimeWindow struct {
	StartTime time.Time
	EndTime   time.Time
	Timezone  string
}

// getMusicStats 获取音乐统计 最多20
func (s *StatsService) getMusicStats(ctx context.Context, userID uint64, window *TimeWindow, topN int32) (*common.StatsSummary, []*common.TopItem, []*common.TopItem, []*common.TopItem, bool, error) {
	// 先检查缓存
	cacheKey := s.generateCacheKey(userID, window)
	cached, err := s.cache.Get(ctx, cacheKey).Result()
	if err == nil && cached != "" {
		// 反序列化缓存的数据
		var cachedStats struct {
			Summary    *common.StatsSummary `json:"summary"`
			TopArtists []*common.TopItem    `json:"topArtists"`
			TopTracks  []*common.TopItem    `json:"topTracks"`
			TopAlbums  []*common.TopItem    `json:"topAlbums"`
		}

		if err := json.Unmarshal([]byte(cached), &cachedStats); err == nil {
			logrus.Debugf("Cache hit for stats: %s", cacheKey)

			// 对缓存的数据应用topN限制
			topArtists := cachedStats.TopArtists
			if int32(len(topArtists)) > topN {
				topArtists = topArtists[:topN]
			}

			topTracks := cachedStats.TopTracks
			if int32(len(topTracks)) > topN {
				topTracks = topTracks[:topN]
			}

			topAlbums := cachedStats.TopAlbums
			if int32(len(topAlbums)) > topN {
				topAlbums = topAlbums[:topN]
			}

			return cachedStats.Summary, topArtists, topTracks, topAlbums, true, nil
		} else {
			logrus.Warnf("Failed to unmarshal cached stats: %v", err)
		}
	}

	// 查询历史状态数据
	var histories []model.StateHistory
	err = s.db.WithContext(ctx).
		Where("user_id = ? AND recorded_at >= ? AND recorded_at <= ?",
			userID, window.StartTime, window.EndTime).
		Order("recorded_at ASC").
		Find(&histories).Error
	if err != nil {
		return nil, nil, nil, nil, false, fmt.Errorf("failed to query state history: %w", err)
	}

	// 分析音乐数据
	summary, topArtists, topTracks, topAlbums := s.analyzeMusicData(histories, 20)

	// 缓存结果，使用用户特定的过期时间
	// 注意：缓存时不应用topN限制，保存完整数据
	cacheData := map[string]interface{}{
		"summary":    summary,
		"topArtists": topArtists,
		"topTracks":  topTracks,
		"topAlbums":  topAlbums,
	}
	if cacheJSON, err := json.Marshal(cacheData); err == nil {
		cacheTTL := s.calculateCacheTTL(userID)
		s.cache.Set(ctx, cacheKey, string(cacheJSON), cacheTTL)
	}

	return summary, topArtists, topTracks, topAlbums, false, nil
}

// generateCacheKey 生成缓存key，使用对齐后的时间窗口
func (s *StatsService) generateCacheKey(userID uint64, window *TimeWindow) string {
	return fmt.Sprintf("stats:%d:%s:%d:%d",
		userID,
		window.Timezone,
		window.StartTime.Unix(),
		window.EndTime.Unix())
}

// calculateCacheTTL 计算用户特定的缓存过期时间，避免同时过期
func (s *StatsService) calculateCacheTTL(userID uint64) time.Duration {
	// 基础缓存时间：1小时
	baseTTL := time.Hour

	// 根据用户ID计算固定偏移量（5-20分钟）
	// 使用用户ID的模运算确保同一用户总是得到相同的偏移量
	offsetMinutes := 5 + (userID % 16) // 5-20分钟的偏移
	offset := time.Duration(offsetMinutes) * time.Minute

	return baseTTL + offset
}

// analyzeMusicData 分析音乐数据
func (s *StatsService) analyzeMusicData(histories []model.StateHistory, topN int32) (*common.StatsSummary, []*common.TopItem, []*common.TopItem, []*common.TopItem) {
	// 统计数据结构
	trackStats := make(map[string]*TrackStat)   // track -> stats
	artistStats := make(map[string]*ArtistStat) // artist -> stats
	albumStats := make(map[string]*AlbumStat)   // album -> stats

	for _, history := range histories {
		snapshot := history.Snapshot.Data()

		// 提取音乐信息
		if snapshot.Music == nil {
			continue
		}

		music := &common.Music{}
		if snapshot.Music.Title != nil {
			music.Title = snapshot.Music.Title
		}
		if snapshot.Music.Artist != nil {
			music.Artist = snapshot.Music.Artist
		}
		if snapshot.Music.Album != nil {
			music.Album = snapshot.Music.Album
		}

		// 直接统计当前音乐数据
		s.updateTrackStats(trackStats, music)
		s.updateArtistStats(artistStats, music)
		s.updateAlbumStats(albumStats, music)
	}

	// 转换为API格式
	return s.convertToStatsResponse(trackStats, artistStats, albumStats, topN)
}

// TrackStat 曲目统计
type TrackStat struct {
	Title     string
	Artist    string
	PlayCount int64
}

// ArtistStat 艺术家统计
type ArtistStat struct {
	Name       string
	TrackCount int64
}

// AlbumStat 专辑统计
type AlbumStat struct {
	Name       string
	Artist     string
	TrackCount int64
}

// updateTrackStats 更新曲目统计
func (s *StatsService) updateTrackStats(trackStats map[string]*TrackStat, music *common.Music) {
	if music.Title == nil || music.Artist == nil {
		return
	}

	trackKey := *music.Title + " - " + *music.Artist
	if trackStats[trackKey] == nil {
		trackStats[trackKey] = &TrackStat{
			Title:     *music.Title,
			Artist:    *music.Artist,
			PlayCount: 0,
		}
	}

	trackStats[trackKey].PlayCount++
}

// updateArtistStats 更新艺术家统计
func (s *StatsService) updateArtistStats(artistStats map[string]*ArtistStat, music *common.Music) {
	if music.Artist == nil {
		return
	}

	artistKey := *music.Artist
	if artistStats[artistKey] == nil {
		artistStats[artistKey] = &ArtistStat{
			Name:       *music.Artist,
			TrackCount: 0,
		}
	}

	artistStats[artistKey].TrackCount++
}

// updateAlbumStats 更新专辑统计
func (s *StatsService) updateAlbumStats(albumStats map[string]*AlbumStat, music *common.Music) {
	if music.Album == nil || music.Artist == nil {
		return
	}

	albumKey := *music.Album + " - " + *music.Artist
	if albumStats[albumKey] == nil {
		albumStats[albumKey] = &AlbumStat{
			Name:       *music.Album,
			Artist:     *music.Artist,
			TrackCount: 0,
		}
	}

	albumStats[albumKey].TrackCount++
}

// convertToStatsResponse 转换为统计响应API格式
func (s *StatsService) convertToStatsResponse(trackStats map[string]*TrackStat, artistStats map[string]*ArtistStat, albumStats map[string]*AlbumStat, topN int32) (*common.StatsSummary, []*common.TopItem, []*common.TopItem, []*common.TopItem) {
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
	gslice.SortBy(topArtists, func(a, b *common.TopItem) bool {
		return a.Count > b.Count
	})
	// 限制返回的艺术家数量
	if int32(len(topArtists)) > topN {
		topArtists = topArtists[:topN]
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
	gslice.SortBy(topTracks, func(a, b *common.TopItem) bool {
		return a.Count > b.Count
	})
	// 限制返回的曲目数量
	if int32(len(topTracks)) > topN {
		topTracks = topTracks[:topN]
	}

	var topAlbums []*common.TopItem
	// 转换专辑统计为TopItem（按曲目数排序）
	if len(albumStats) > 0 {
		topAlbums = make([]*common.TopItem, 0, len(albumStats))
		for _, stat := range albumStats {
			topItem := &common.TopItem{
				Name:  stat.Name + " - " + stat.Artist,
				Count: int32(stat.TrackCount),
			}
			topAlbums = append(topAlbums, topItem)
		}
	}
	gslice.SortBy(topAlbums, func(a, b *common.TopItem) bool {
		return a.Count > b.Count
	})
	// 限制返回的专辑数量
	if int32(len(topAlbums)) > topN {
		topAlbums = topAlbums[:topN]
	}

	return summary, topArtists, topTracks, topAlbums
}
