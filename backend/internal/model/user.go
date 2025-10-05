package model

import (
	"time"

	common "share-my-status/api/model/share_my_status/common"

	"gorm.io/datatypes"
	"gorm.io/gorm"
)

// User 用户表
type User struct {
	ID         uint64    `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	OpenID     string    `gorm:"column:open_id;type:varchar(64);uniqueIndex;not null" json:"openId"`
	SecretKey  []byte    `gorm:"column:secret_key;type:varbinary(64);uniqueIndex;not null" json:"secretKey"`
	SharingKey string    `gorm:"column:sharing_key;type:varchar(64);uniqueIndex;not null" json:"sharingKey"`
	Status     int       `gorm:"column:status;type:tinyint;not null;default:1" json:"status"`
	CreatedAt  time.Time `gorm:"column:created_at" json:"createdAt"`
	UpdatedAt  time.Time `gorm:"column:updated_at" json:"updatedAt"`
}

// TableName 指定表名
func (User) TableName() string {
	return "users"
}

// UserSettingsPayload 用户设置载荷
type UserSettingsPayload struct {
	PublicEnabled        bool `json:"publicEnabled"`
	AuthorizedMusicStats bool `json:"authorizedMusicStats"`
}

// UserSettings 用户设置表
type UserSettings struct {
	OpenID    string                                  `gorm:"column:open_id;type:varchar(64);primaryKey" json:"openId"`
	Settings  datatypes.JSONType[UserSettingsPayload] `gorm:"column:settings;type:json;not null" json:"settings"`
	UpdatedAt time.Time                               `gorm:"column:updated_at;autoUpdateTime" json:"updatedAt"`
}

// TableName 指定表名
func (UserSettings) TableName() string {
	return "user_settings"
}

// CurrentState 当前状态表
type CurrentState struct {
	OpenID    string                                    `gorm:"column:open_id;type:varchar(64);primaryKey" json:"openId"`
	Snapshot  datatypes.JSONType[common.StatusSnapshot] `gorm:"column:snapshot;type:json;not null" json:"snapshot"`
	UpdatedAt time.Time                                 `gorm:"column:updated_at;autoUpdateTime" json:"updatedAt"`
}

// TableName 指定表名
func (CurrentState) TableName() string {
	return "current_state"
}

// StateHistory 历史状态表
type StateHistory struct {
	ID         uint64                                    `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	OpenID     string                                    `gorm:"column:open_id;type:varchar(64);index:ix_hist_user_time,priority:1" json:"openId"`
	RecordedAt time.Time                                 `gorm:"column:recorded_at;index:ix_hist_user_time,priority:2" json:"recordedAt"`
	Snapshot   datatypes.JSONType[common.StatusSnapshot] `gorm:"column:snapshot;type:json;not null" json:"snapshot"`
}

// TableName 指定表名
func (StateHistory) TableName() string {
	return "state_history"
}

// CoverAssetPayload 封面资源载荷
type CoverAssetPayload struct {
	FilePath    string `json:"filePath"` // 文件存储路径
	B64         string `json:"b64"`      // base64编码数据（用于小文件）
	ContentType string `json:"contentType"`
	Size        int64  `json:"size"`
	UploadTime  int64  `json:"uploadTime"`
	StorageType string `json:"storageType"` // "file" 或 "base64"
}

// CoverAsset 封面资源表
type CoverAsset struct {
	CoverHash string                                `gorm:"column:cover_hash;type:char(32);primaryKey" json:"coverHash"`
	Asset     datatypes.JSONType[CoverAssetPayload] `gorm:"column:asset;type:json;not null" json:"asset"`
	CreatedAt time.Time                             `gorm:"column:created_at" json:"createdAt"`
	UpdatedAt time.Time                             `gorm:"column:updated_at" json:"updatedAt"`
}

// TableName 指定表名
func (CoverAsset) TableName() string {
	return "cover_assets"
}

// MusicStatsPayload 音乐统计载荷
type MusicStatsPayload struct {
	Summary    *common.StatsSummary `json:"summary"`
	TopArtists []*common.TopItem    `json:"topArtists"`
	TopTracks  []*common.TopItem    `json:"topTracks"`
}

// MusicStats 音乐统计表
type MusicStats struct {
	ID         uint64                                `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	OpenID     string                                `gorm:"column:open_id;type:varchar(64);index:uk_user_window,unique,priority:1" json:"openId"`
	WindowType string                                `gorm:"column:window_type;type:enum('rolling_3d','rolling_7d','month_to_date','year_to_date','custom');index:uk_user_window,unique,priority:2" json:"windowType"`
	Tz         string                                `gorm:"column:tz;size:32;not null" json:"tz"`
	StartTime  time.Time                             `gorm:"column:start_time;index:uk_user_window,unique,priority:3" json:"startTime"`
	EndTime    time.Time                             `gorm:"column:end_time;index:uk_user_window,unique,priority:4" json:"endTime"`
	Stats      datatypes.JSONType[MusicStatsPayload] `gorm:"column:stats;type:json;not null" json:"stats"`
	CreatedAt  time.Time                             `gorm:"column:created_at" json:"createdAt"`
	UpdatedAt  time.Time                             `gorm:"column:updated_at" json:"updatedAt"`
}

// TableName 指定表名
func (MusicStats) TableName() string {
	return "music_stats"
}

// CreateTables 创建数据库表
func CreateTables(db *gorm.DB) error {
	return db.AutoMigrate(
		&User{},
		&UserSettings{},
		&CurrentState{},
		&StateHistory{},
		&CoverAsset{},
		&MusicStats{},
	)
}
