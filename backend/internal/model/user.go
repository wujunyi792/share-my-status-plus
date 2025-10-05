package model

import (
	"time"

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

// UserSettings 用户设置表
type UserSettings struct {
	OpenID    string                 `gorm:"column:open_id;type:varchar(64);primaryKey" json:"openId"`
	Settings  map[string]interface{} `gorm:"column:settings;type:json;not null" json:"settings"`
	UpdatedAt time.Time              `gorm:"column:updated_at;autoUpdateTime" json:"updatedAt"`
}

// TableName 指定表名
func (UserSettings) TableName() string {
	return "user_settings"
}

// CurrentState 当前状态表
type CurrentState struct {
	OpenID    string                 `gorm:"column:open_id;type:varchar(64);primaryKey" json:"openId"`
	Snapshot  map[string]interface{} `gorm:"column:snapshot;type:json;not null" json:"snapshot"`
	UpdatedAt time.Time              `gorm:"column:updated_at;autoUpdateTime" json:"updatedAt"`
}

// TableName 指定表名
func (CurrentState) TableName() string {
	return "current_state"
}

// StateHistory 历史状态表
type StateHistory struct {
	ID         uint64                 `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	OpenID     string                 `gorm:"column:open_id;type:varchar(64);index:ix_hist_user_time,priority:1" json:"openId"`
	RecordedAt time.Time              `gorm:"column:recorded_at;index:ix_hist_user_time,priority:2" json:"recordedAt"`
	Snapshot   map[string]interface{} `gorm:"column:snapshot;type:json;not null" json:"snapshot"`
}

// TableName 指定表名
func (StateHistory) TableName() string {
	return "state_history"
}

// CoverAsset 封面资源表
type CoverAsset struct {
	CoverHash string                 `gorm:"column:cover_hash;type:char(32);primaryKey" json:"coverHash"`
	Asset     map[string]interface{} `gorm:"column:asset;type:json;not null" json:"asset"`
	CreatedAt time.Time              `gorm:"column:created_at" json:"createdAt"`
	UpdatedAt time.Time              `gorm:"column:updated_at" json:"updatedAt"`
}

// TableName 指定表名
func (CoverAsset) TableName() string {
	return "cover_assets"
}

// MusicStats 音乐统计表
type MusicStats struct {
	ID         uint64                 `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	OpenID     string                 `gorm:"column:open_id;type:varchar(64);index:uk_user_window,unique,priority:1" json:"openId"`
	WindowType string                 `gorm:"column:window_type;type:enum('rolling_3d','rolling_7d','month_to_date','year_to_date','custom');index:uk_user_window,unique,priority:2" json:"windowType"`
	Tz         string                 `gorm:"column:tz;size:32;not null" json:"tz"`
	StartTime  time.Time              `gorm:"column:start_time;index:uk_user_window,unique,priority:3" json:"startTime"`
	EndTime    time.Time              `gorm:"column:end_time;index:uk_user_window,unique,priority:4" json:"endTime"`
	Stats      map[string]interface{} `gorm:"column:stats;type:json;not null" json:"stats"`
	CreatedAt  time.Time              `gorm:"column:created_at" json:"createdAt"`
	UpdatedAt  time.Time              `gorm:"column:updated_at" json:"updatedAt"`
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
