package user

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"share-my-status/model"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"github.com/sirupsen/logrus"
	"gorm.io/datatypes"
	"gorm.io/gorm"
)

type UserService struct {
	db    *gorm.DB
	cache *redis.Client
}

func NewUserService(db *gorm.DB, cache *redis.Client) *UserService {
	return &UserService{
		db:    db,
		cache: cache,
	}
}

// CreateUser 创建用户
func (s *UserService) CreateUser(openID string) (*model.User, error) {
	// 生成密钥
	secretKey, err := s.generateSecretKey()
	if err != nil {
		return nil, fmt.Errorf("failed to generate secret key: %w", err)
	}

	sharingKey, err := s.generateSharingKey()
	if err != nil {
		return nil, fmt.Errorf("failed to generate sharing key: %w", err)
	}

	// 创建用户
	user := &model.User{
		OpenID:     openID,
		SecretKey:  []byte(secretKey),
		SharingKey: sharingKey,
		Status:     1,
	}

	if err := s.db.Create(user).Error; err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	// 创建默认用户设置
	defaultSettings := &model.UserSettings{
		UserID: user.ID,
		Settings: datatypes.NewJSONType(model.UserSettingsPayload{
			AuthorizedMusicStats: false,
			PublicEnabled:        true,
		}),
	}

	if err := s.db.Create(defaultSettings).Error; err != nil {
		logrus.Errorf("Failed to create user settings: %v", err)
		// 不返回错误，因为用户已经创建成功
	}

	logrus.Infof("User created successfully: %s", openID)
	return user, nil
}

// GetUserByID 通过ID获取用户
func (s *UserService) GetUserByID(userID uint64) (*model.User, error) {
	var user model.User
	err := s.db.Where("id = ?", userID).First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// GetUserByOpenID 通过OpenID获取用户
func (s *UserService) GetUserByOpenID(openID string) (*model.User, error) {
	var user model.User
	err := s.db.Where("open_id = ?", openID).First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// GetUserBySecretKey 通过Secret Key获取用户
func (s *UserService) GetUserBySecretKey(secretKey string) (*model.User, error) {
	var user model.User
	err := s.db.Where("secret_key = ?", secretKey).First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// GetUserBySharingKey 通过Sharing Key获取用户
func (s *UserService) GetUserBySharingKey(sharingKey string) (*model.User, error) {
	var user model.User
	err := s.db.Where("sharing_key = ?", sharingKey).First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// UpdateUserSettings 更新用户设置
func (s *UserService) UpdateUserSettings(userID uint64, settings model.UserSettingsPayload) error {
	var userSettings model.UserSettings
	err := s.db.Where("user_id = ?", userID).First(&userSettings).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			// 创建新的用户设置
			userSettings = model.UserSettings{
				UserID:   userID,
				Settings: datatypes.NewJSONType(settings),
			}
			return s.db.Create(&userSettings).Error
		}
		return err
	}

	// 更新设置
	userSettings.Settings = datatypes.NewJSONType(settings)
	return s.db.Save(&userSettings).Error
}

// GetUserSettings 获取用户设置
func (s *UserService) GetUserSettings(userID uint64) (*model.UserSettings, error) {
	var settings model.UserSettings
	err := s.db.Where("user_id = ?", userID).First(&settings).Error
	if err != nil {
		return nil, err
	}
	return &settings, nil
}

// RotateSecretKey 轮转Secret Key
func (s *UserService) RotateSecretKey(userID uint64) (string, error) {
	newSecretKey, err := s.generateSecretKey()
	if err != nil {
		return "", fmt.Errorf("failed to generate new secret key: %w", err)
	}

	hash := sha256.Sum256([]byte(newSecretKey))
	secretKeyHash := hex.EncodeToString(hash[:])

	err = s.db.Model(&model.User{}).Where("id = ?", userID).Update("secret_key", secretKeyHash).Error
	if err != nil {
		return "", fmt.Errorf("failed to update secret key: %w", err)
	}

	logrus.Infof("Secret key rotated for user: %d", userID)
	return newSecretKey, nil
}

// RotateSharingKey 轮转Sharing Key
func (s *UserService) RotateSharingKey(userID uint64) (string, error) {
	newSharingKey, err := s.generateSharingKey()
	if err != nil {
		return "", fmt.Errorf("failed to generate new sharing key: %w", err)
	}

	err = s.db.Model(&model.User{}).Where("id = ?", userID).Update("sharing_key", newSharingKey).Error
	if err != nil {
		return "", fmt.Errorf("failed to update sharing key: %w", err)
	}

	logrus.Infof("Sharing key rotated for user: %d", userID)
	return newSharingKey, nil
}

// generateSecretKey 生成Secret Key
func (s *UserService) generateSecretKey() (string, error) {
	bytes := make([]byte, 32)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}

// generateSharingKey 生成Sharing Key
func (s *UserService) generateSharingKey() (string, error) {
	// 使用UUID生成Sharing Key
	id := uuid.New()
	return id.String(), nil
}

// IsPublicEnabled 检查用户是否开启公开访问
func (s *UserService) IsPublicEnabled(userID uint64) (bool, error) {
	settings, err := s.GetUserSettings(userID)
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			// 默认开启公开访问
			return true, nil
		}
		return false, err
	}

	return settings.Settings.Data().PublicEnabled, nil
}

// IsMusicStatsAuthorized 检查用户是否授权音乐统计
func (s *UserService) IsMusicStatsAuthorized(userID uint64) (bool, error) {
	settings, err := s.GetUserSettings(userID)
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			// 默认未授权
			return false, nil
		}
		return false, err
	}

	return settings.Settings.Data().AuthorizedMusicStats, nil
}
