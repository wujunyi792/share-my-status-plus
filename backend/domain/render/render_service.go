package render

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	common "share-my-status/api/model/share_my_status/common"
	"share-my-status/domain/user"
	"share-my-status/pkg/dbutil"

	"gorm.io/gorm"
)

const (
	DefaultTemplate     = "正在听{artist}-{title}"
	DefaultPreviewTitle = "未在播放音乐"
	DefaultImageKey     = "img_v3_02e1_e30f851f-c7c1-4c58-8366-3494186fcbeg"
)

var (
	ErrSharingKeyNotFound   = errors.New("sharing key not found")
	ErrPublicAccessDisabled = errors.New("public access is disabled")
)

type Service struct {
	db          *gorm.DB
	userService *user.UserService
}

type PreviewResponse struct {
	Inline *Inline `json:"inline,omitempty"`
}

type Inline struct {
	Title     string            `json:"title,omitempty"`
	I18nTitle map[string]string `json:"i18n_title,omitempty"`
	ImageKey  string            `json:"image_key,omitempty"`
	URL       *URL              `json:"url,omitempty"`
}

type URL struct {
	CopyURL string `json:"copy_url,omitempty"`
	IOS     string `json:"ios,omitempty"`
	Android string `json:"android,omitempty"`
	PC      string `json:"pc,omitempty"`
	Web     string `json:"web,omitempty"`
}

func NewRenderService(db *gorm.DB, userService *user.UserService) *Service {
	return &Service{
		db:          db,
		userService: userService,
	}
}

func NewDefaultPreview() *PreviewResponse {
	return &PreviewResponse{
		Inline: &Inline{
			Title:    DefaultPreviewTitle,
			ImageKey: DefaultImageKey,
		},
	}
}

func (s *Service) RenderBySharingKey(ctx context.Context, sharingKey string, template string) (*PreviewResponse, error) {
	u, err := s.userService.GetUserBySharingKey(sharingKey)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrSharingKeyNotFound
		}
		return nil, fmt.Errorf("failed to get user by sharing key: %w", err)
	}

	return s.RenderByUserID(ctx, u.ID, template)
}

func (s *Service) RenderByUserID(ctx context.Context, userID uint64, template string) (*PreviewResponse, error) {
	publicEnabled, err := s.userService.IsPublicEnabled(userID)
	if err != nil {
		return nil, fmt.Errorf("failed to check public access: %w", err)
	}
	if !publicEnabled {
		return nil, ErrPublicAccessDisabled
	}

	currentState, err := dbutil.GetCurrentStateFromDB(ctx, s.db, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get current state: %w", err)
	}

	preview := NewDefaultPreview()
	preview.Inline.Title = RenderTemplate(normalizeTemplate(template), currentState)
	return preview, nil
}

func normalizeTemplate(template string) string {
	if template == "" {
		return DefaultTemplate
	}
	return template
}

func RenderTemplate(template string, state *common.StatusSnapshot) string {
	if state == nil {
		result := strings.ReplaceAll(template, "{artist}", "")
		result = strings.ReplaceAll(result, "{title}", "未在播放")
		result = strings.ReplaceAll(result, "{album}", "")
		result = strings.ReplaceAll(result, "{activityLabel}", "")
		result = renderTimeVariables(result)
		result = renderSystemVariables(result, nil)
		result = renderConditionalVariables(result, nil)
		return result
	}

	result := template
	result = renderMusicVariables(result, state.Music)
	result = renderSystemVariables(result, state.System)
	result = renderActivityVariables(result, state.Activity)
	result = renderTimeVariables(result)
	result = renderConditionalVariables(result, state.System)

	return result
}

func renderMusicVariables(template string, music *common.Music) string {
	result := template

	if music != nil {
		artist := ""
		title := ""
		album := ""

		if music.Artist != nil {
			artist = *music.Artist
		}
		if music.Title != nil {
			title = *music.Title
		}
		if music.Album != nil {
			album = *music.Album
		}

		result = strings.ReplaceAll(result, "{artist}", artist)
		result = strings.ReplaceAll(result, "{title}", title)
		result = strings.ReplaceAll(result, "{album}", album)
	} else {
		result = strings.ReplaceAll(result, "{artist}", "")
		result = strings.ReplaceAll(result, "{title}", "未在播放")
		result = strings.ReplaceAll(result, "{album}", "")
	}

	return result
}

func renderSystemVariables(template string, system *common.System) string {
	result := template

	if system != nil {
		if system.BatteryPct != nil {
			batteryPct := *system.BatteryPct
			result = strings.ReplaceAll(result, "{batteryPct}", fmt.Sprintf("%.2f", batteryPct))
			result = strings.ReplaceAll(result, "{batteryPctRounded}", fmt.Sprintf("%.0f%%", batteryPct*100))
		} else {
			result = strings.ReplaceAll(result, "{batteryPct}", "")
			result = strings.ReplaceAll(result, "{batteryPctRounded}", "")
		}

		if system.CpuPct != nil {
			cpuPct := *system.CpuPct
			result = strings.ReplaceAll(result, "{cpuPct}", fmt.Sprintf("%.2f", cpuPct))
			result = strings.ReplaceAll(result, "{cpuPctRounded}", fmt.Sprintf("%.0f%%", cpuPct*100))
		} else {
			result = strings.ReplaceAll(result, "{cpuPct}", "")
			result = strings.ReplaceAll(result, "{cpuPctRounded}", "")
		}

		if system.MemoryPct != nil {
			memoryPct := *system.MemoryPct
			result = strings.ReplaceAll(result, "{memoryPct}", fmt.Sprintf("%.2f", memoryPct))
			result = strings.ReplaceAll(result, "{memoryPctRounded}", fmt.Sprintf("%.0f%%", memoryPct*100))
		} else {
			result = strings.ReplaceAll(result, "{memoryPct}", "")
			result = strings.ReplaceAll(result, "{memoryPctRounded}", "")
		}
	} else {
		result = strings.ReplaceAll(result, "{batteryPct}", "")
		result = strings.ReplaceAll(result, "{batteryPctRounded}", "")
		result = strings.ReplaceAll(result, "{cpuPct}", "")
		result = strings.ReplaceAll(result, "{cpuPctRounded}", "")
		result = strings.ReplaceAll(result, "{memoryPct}", "")
		result = strings.ReplaceAll(result, "{memoryPctRounded}", "")
	}

	return result
}

func renderActivityVariables(template string, activity *common.Activity) string {
	result := template

	if activity != nil && activity.Label != "" {
		result = strings.ReplaceAll(result, "{activityLabel}", activity.Label)
	} else {
		result = strings.ReplaceAll(result, "{activityLabel}", "")
	}

	return result
}

func renderTimeVariables(template string) string {
	result := template
	now := time.Now()

	result = strings.ReplaceAll(result, "{nowLocal}", now.Format("2006-01-02 15:04:05"))
	result = strings.ReplaceAll(result, "{dateYMD}", now.Format("2006-01-02"))
	result = strings.ReplaceAll(result, "{nowISO}", now.Format(time.RFC3339))

	return result
}

func renderConditionalVariables(template string, system *common.System) string {
	result := template

	if strings.Contains(result, "{charging?") {
		charging := false
		if system != nil && system.Charging != nil {
			charging = *system.Charging
		}

		if charging {
			result = strings.ReplaceAll(result, "{charging?'充电中':'未充电'}", "充电中")
			result = strings.ReplaceAll(result, "{charging?'充电中':'未在充电'}", "充电中")
		} else {
			result = strings.ReplaceAll(result, "{charging?'充电中':'未充电'}", "未充电")
			result = strings.ReplaceAll(result, "{charging?'充电中':'未在充电'}", "未在充电")
		}
	}

	return result
}
