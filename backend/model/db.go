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
	UserID    uint64                                  `gorm:"column:user_id;primaryKey" json:"userId"`
	Settings  datatypes.JSONType[UserSettingsPayload] `gorm:"column:settings;type:json;not null" json:"settings"`
	UpdatedAt time.Time                               `gorm:"column:updated_at;autoUpdateTime" json:"updatedAt"`
}

// TableName 指定表名
func (UserSettings) TableName() string {
	return "user_settings"
}

// CurrentState 当前状态表
type CurrentState struct {
	UserID    uint64                                    `gorm:"column:user_id;primaryKey" json:"userId"`
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
	UserID     uint64                                    `gorm:"column:user_id;index:ix_hist_user_time,priority:1" json:"userId"`
	RecordedAt time.Time                                 `gorm:"column:recorded_at;index:ix_hist_user_time,priority:2" json:"recordedAt"`
	Snapshot   datatypes.JSONType[common.StatusSnapshot] `gorm:"column:snapshot;type:json;not null" json:"snapshot"`
}

// TableName 指定表名
func (StateHistory) TableName() string {
	return "state_history"
}

// CoverAssetPayload 封面资源载荷
type CoverAssetPayload struct {
	B64         string `json:"b64"` // base64编码数据
	ContentType string `json:"contentType"`
	Size        int64  `json:"size"`
	UploadTime  int64  `json:"uploadTime"`
	StorageType string `json:"storageType"` // 固定为 "base64"
}

// CoverAsset 封面资源表
type CoverAsset struct {
	CoverHash string                                `gorm:"column:cover_hash;type:char(32);primaryKey" json:"coverHash"`
	LarkKey   string                                `gorm:"column:lark_key;type:varchar(64);" json:"larkKey"`
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

// ClientVersion 客户端版本信息表
// 用于存储不同平台最新版本信息
// 平台取值：windows、macos
type ClientVersion struct {
	ID          uint64    `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	Platform    string    `gorm:"column:platform;type:varchar(16);index:ix_platform" json:"platform"`
	Version     string    `gorm:"column:version;type:varchar(32);not null" json:"version"`
	BuildNumber int       `gorm:"column:build_number;type:int;not null" json:"buildNumber"`
	DownloadUrl string    `gorm:"column:download_url;type:varchar(255);not null" json:"downloadUrl"`
	ReleaseNote string    `gorm:"column:release_note;type:text" json:"releaseNote"`
	ForceUpdate bool      `gorm:"column:force_update;type:tinyint(1);not null;default:false" json:"forceUpdate"`
	CreatedAt   time.Time `gorm:"column:created_at" json:"createdAt"`
	UpdatedAt   time.Time `gorm:"column:updated_at" json:"updatedAt"`
}

// TableName 指定表名
func (ClientVersion) TableName() string {
	return "client_versions"
}

// CreateTables 创建数据库表
func CreateTables(db *gorm.DB) error {
	return db.AutoMigrate(
		&User{},
		&UserSettings{},
		&CurrentState{},
		&StateHistory{},
		&CoverAsset{},
		&ClientVersion{},
	)
}
