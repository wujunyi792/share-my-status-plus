package lark

import (
	"context"
	"fmt"
	"net/url"
	"strings"
	"time"

	"share-my-status/internal/database"
	"share-my-status/internal/model"
	"share-my-status/internal/service"

	"github.com/larksuite/oapi-sdk-go/v3/event/dispatcher/callback"
	larkim "github.com/larksuite/oapi-sdk-go/v3/service/im/v1"
	"github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

// OnP2MessageReceiveV1 处理飞书消息接收事件
func OnP2MessageReceiveV1(ctx context.Context, event *larkim.P2MessageReceiveV1) error {
	openID := *event.Event.Sender.SenderId.OpenId
	message := ""
	if event.Event.Message.Content != nil {
		message = *event.Event.Message.Content
	}

	logrus.Infof("Received message from user %s: %s", openID, message)

	// 解析命令
	command := parseCommand(message)
	if command == nil {
		return nil // 忽略非命令消息
	}

	// 获取或创建用户
	userService := service.NewUserService()
	user, err := userService.GetUserByOpenID(openID)
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			// 创建新用户
			user, err = userService.CreateUser(openID)
			if err != nil {
				logrus.Errorf("Failed to create user: %v", err)
				return sendMessage(ctx, openID, "❌ 创建用户失败，请稍后重试")
			}
		} else {
			logrus.Errorf("Failed to get user: %v", err)
			return sendMessage(ctx, openID, "❌ 获取用户信息失败")
		}
	}

	// 执行命令
	response, err := executeCommand(ctx, user, command)
	if err != nil {
		logrus.Errorf("Failed to execute command: %v", err)
		return sendMessage(ctx, openID, fmt.Sprintf("❌ 执行命令失败: %v", err))
	}

	return sendMessage(ctx, openID, response)
}

// OnP2CardURLPreviewGet 处理链接预览事件
func OnP2CardURLPreviewGet(ctx context.Context, event *callback.URLPreviewGetEvent) (*callback.URLPreviewGetResponse, error) {
	logrus.Infof("URL preview request: %s", event.Event.Context.URL)

	// 默认预览
	urlPreview := &callback.URLPreviewGetResponse{
		Inline: &callback.Inline{
			Title:    "未在播放音乐",
			ImageKey: "img_v3_02e1_e30f851f-c7c1-4c58-8366-3494186fcbeg", // 默认图片
		},
	}

	// 解析URL
	parsedURL, err := url.Parse(event.Event.Context.URL)
	if err != nil {
		logrus.Errorf("Failed to parse URL: %v", err)
		return urlPreview, nil
	}

	// 提取参数
	sharingKey := extractSharingKey(parsedURL.Path)
	template := parsedURL.Query().Get("m")
	if template == "" {
		template = "{artist}的{title}"
	}

	if sharingKey == "" {
		logrus.Warn("No sharing key found in URL")
		return urlPreview, nil
	}

	// 获取用户状态
	userService := service.NewUserService()
	user, err := userService.GetUserBySharingKey(sharingKey)
	if err != nil {
		logrus.Errorf("Failed to get user by sharing key: %v", err)
		return urlPreview, nil
	}

	// 检查公开访问权限
	publicEnabled, err := userService.IsPublicEnabled(user.OpenID)
	if err != nil {
		logrus.Errorf("Failed to check public access: %v", err)
		return urlPreview, nil
	}

	if !publicEnabled {
		urlPreview.Inline.Title = "未开启公开访问"
		return urlPreview, nil
	}

	// 获取当前状态
	currentState, err := getCurrentState(ctx, user.OpenID)
	if err != nil {
		logrus.Errorf("Failed to get current state: %v", err)
		return urlPreview, nil
	}

	// 渲染模板
	title := renderTemplate(template, currentState)
	urlPreview.Inline.Title = title

	// 如果有封面，设置封面图片
	if currentState.Music != nil && currentState.Music.CoverHash != nil {
		// 这里应该设置实际的封面图片，暂时使用默认图片
		// urlPreview.Inline.ImageKey = getCoverImageKey(*currentState.Music.CoverHash)
	}

	// 记录预览历史
	if event.Event.Context.PreviewToken != "" {
		recordPreviewHistory(ctx, user.ID, event.Event.Context.PreviewToken, event.Event.Operator.OpenID)
	}

	return urlPreview, nil
}

// Command 命令结构
type Command struct {
	Action string
	Params []string
}

// parseCommand 解析命令
func parseCommand(message string) *Command {
	message = strings.TrimSpace(message)
	if !strings.HasPrefix(message, "/status") {
		return nil
	}

	parts := strings.Fields(message)
	if len(parts) < 2 {
		return nil
	}

	return &Command{
		Action: parts[1],
		Params: parts[2:],
	}
}

// executeCommand 执行命令
func executeCommand(ctx context.Context, user *model.User, command *Command) (string, error) {
	userService := service.NewUserService()

	switch command.Action {
	case "revoke":
		return executeRevokeCommand(ctx, user, userService)
	case "rotate":
		return executeRotateCommand(ctx, user, userService)
	case "publish":
		return executePublishCommand(ctx, user, userService, command.Params)
	case "info":
		return executeInfoCommand(ctx, user, userService)
	default:
		return "❓ 未知命令。支持的命令：\n• `/status revoke` - 撤销公开链接\n• `/status rotate` - 轮转密钥\n• `/status publish on|off` - 开启/关闭公开访问\n• `/status info` - 查看账户信息", nil
	}
}

// executeRevokeCommand 执行撤销命令
func executeRevokeCommand(ctx context.Context, user *model.User, userService *service.UserService) (string, error) {
	// 生成新的Sharing Key
	newSharingKey, err := userService.RotateSharingKey(user.OpenID)
	if err != nil {
		return "", fmt.Errorf("failed to rotate sharing key: %w", err)
	}

	return fmt.Sprintf("✅ 公开链接已撤销并重新生成\n🔗 新链接: https://status.example.com/s/%s\n⚠️ 请更新您的分享链接", newSharingKey), nil
}

// executeRotateCommand 执行轮转命令
func executeRotateCommand(ctx context.Context, user *model.User, userService *service.UserService) (string, error) {
	// 生成新的Secret Key
	newSecretKey, err := userService.RotateSecretKey(user.OpenID)
	if err != nil {
		return "", fmt.Errorf("failed to rotate secret key: %w", err)
	}

	return fmt.Sprintf("✅ Secret Key已轮转\n🔑 新密钥: %s\n⚠️ 请更新客户端配置", newSecretKey), nil
}

// executePublishCommand 执行发布命令
func executePublishCommand(ctx context.Context, user *model.User, userService *service.UserService, params []string) (string, error) {
	if len(params) != 1 {
		return "❌ 用法: `/status publish on|off`", nil
	}

	enable := params[0] == "on"

	// 获取当前设置
	settings, err := userService.GetUserSettings(user.OpenID)
	if err != nil && err != gorm.ErrRecordNotFound {
		return "", fmt.Errorf("failed to get user settings: %w", err)
	}

	// 更新设置
	newSettings := make(map[string]interface{})
	if settings != nil {
		newSettings = settings.Settings
	}
	newSettings["publicEnabled"] = enable

	err = userService.UpdateUserSettings(user.OpenID, newSettings)
	if err != nil {
		return "", fmt.Errorf("failed to update settings: %w", err)
	}

	status := "关闭"
	if enable {
		status = "开启"
	}

	return fmt.Sprintf("✅ 公开访问已%s\n🔗 分享链接: https://status.example.com/s/%s", status, user.SharingKey), nil
}

// executeInfoCommand 执行信息命令
func executeInfoCommand(ctx context.Context, user *model.User, userService *service.UserService) (string, error) {
	// 获取用户设置
	settings, err := userService.GetUserSettings(user.OpenID)
	if err != nil && err != gorm.ErrRecordNotFound {
		return "", fmt.Errorf("failed to get user settings: %w", err)
	}

	publicEnabled := false
	musicStatsAuthorized := false
	if settings != nil {
		if val, ok := settings.Settings["publicEnabled"].(bool); ok {
			publicEnabled = val
		}
		if val, ok := settings.Settings["authorizedMusicStats"].(bool); ok {
			musicStatsAuthorized = val
		}
	}

	// 获取当前状态
	currentState, err := getCurrentState(ctx, user.OpenID)
	if err != nil {
		logrus.Errorf("Failed to get current state: %v", err)
	}

	status := "未在播放"
	if currentState != nil && currentState.Music != nil {
		if currentState.Music.Title != nil && currentState.Music.Artist != nil {
			status = fmt.Sprintf("%s - %s", *currentState.Music.Artist, *currentState.Music.Title)
		}
	}

	info := fmt.Sprintf("📊 账户信息\n"+
		"🎵 当前状态: %s\n"+
		"🌐 公开访问: %s\n"+
		"📈 音乐统计: %s\n"+
		"🔗 分享链接: https://status.example.com/s/%s",
		status,
		map[bool]string{true: "开启", false: "关闭"}[publicEnabled],
		map[bool]string{true: "已授权", false: "未授权"}[musicStatsAuthorized],
		user.SharingKey)

	return info, nil
}

// extractSharingKey 从URL路径中提取Sharing Key
func extractSharingKey(path string) string {
	// 假设路径格式为 /s/{sharingKey}
	parts := strings.Split(strings.Trim(path, "/"), "/")
	if len(parts) >= 2 && parts[0] == "s" {
		return parts[1]
	}
	return ""
}

// renderTemplate 渲染模板
func renderTemplate(template string, state *StateSnapshot) string {
	if state == nil {
		result := strings.ReplaceAll(template, "{artist}", "")
		result = strings.ReplaceAll(result, "{title}", "未在播放")
		return result
	}

	result := template

	// 替换音乐信息
	if state.Music != nil {
		artist := ""
		title := ""
		album := ""

		if state.Music.Artist != nil {
			artist = *state.Music.Artist
		}
		if state.Music.Title != nil {
			title = *state.Music.Title
		}
		if state.Music.Album != nil {
			album = *state.Music.Album
		}

		result = strings.ReplaceAll(result, "{artist}", artist)
		result = strings.ReplaceAll(result, "{title}", title)
		result = strings.ReplaceAll(result, "{album}", album)
	} else {
		result = strings.ReplaceAll(result, "{artist}", "")
		result = strings.ReplaceAll(result, "{title}", "未在播放")
		result = strings.ReplaceAll(result, "{album}", "")
	}

	// 替换系统信息
	if state.System != nil {
		charging := "未在充电"
		if state.System.Charging != nil && *state.System.Charging {
			charging = "充电中"
		}
		result = strings.ReplaceAll(result, "{charging}", charging)

		if state.System.BatteryPct != nil {
			result = strings.ReplaceAll(result, "{battery}", fmt.Sprintf("%.0f%%", *state.System.BatteryPct))
		}
	}

	// 替换活动信息
	if state.Activity != nil && state.Activity.Label != "" {
		result = strings.ReplaceAll(result, "{activity}", state.Activity.Label)
	}

	return result
}

// StateSnapshot 状态快照
type StateSnapshot struct {
	Music    *MusicInfo    `json:"music,omitempty"`
	System   *SystemInfo   `json:"system,omitempty"`
	Activity *ActivityInfo `json:"activity,omitempty"`
}

// MusicInfo 音乐信息
type MusicInfo struct {
	Title     *string `json:"title,omitempty"`
	Artist    *string `json:"artist,omitempty"`
	Album     *string `json:"album,omitempty"`
	CoverHash *string `json:"coverHash,omitempty"`
}

// SystemInfo 系统信息
type SystemInfo struct {
	BatteryPct *float64 `json:"batteryPct,omitempty"`
	Charging   *bool    `json:"charging,omitempty"`
	CpuPct     *float64 `json:"cpuPct,omitempty"`
	MemoryPct  *float64 `json:"memoryPct,omitempty"`
}

// ActivityInfo 活动信息
type ActivityInfo struct {
	Label string `json:"label"`
}

// getCurrentState 获取当前状态
func getCurrentState(ctx context.Context, openID string) (*StateSnapshot, error) {
	var currentState model.CurrentState
	err := database.GetDB().WithContext(ctx).Where("open_id = ?", openID).First(&currentState).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, nil
		}
		return nil, err
	}

	snapshot := &StateSnapshot{}

	// 解析音乐信息
	if musicData, ok := currentState.Snapshot["music"].(map[string]interface{}); ok {
		music := &MusicInfo{}
		if val, ok := musicData["title"].(string); ok {
			music.Title = &val
		}
		if val, ok := musicData["artist"].(string); ok {
			music.Artist = &val
		}
		if val, ok := musicData["album"].(string); ok {
			music.Album = &val
		}
		if val, ok := musicData["coverHash"].(string); ok {
			music.CoverHash = &val
		}
		snapshot.Music = music
	}

	// 解析系统信息
	if systemData, ok := currentState.Snapshot["system"].(map[string]interface{}); ok {
		system := &SystemInfo{}
		if val, ok := systemData["batteryPct"].(float64); ok {
			system.BatteryPct = &val
		}
		if val, ok := systemData["charging"].(bool); ok {
			system.Charging = &val
		}
		if val, ok := systemData["cpuPct"].(float64); ok {
			system.CpuPct = &val
		}
		if val, ok := systemData["memoryPct"].(float64); ok {
			system.MemoryPct = &val
		}
		snapshot.System = system
	}

	// 解析活动信息
	if activityData, ok := currentState.Snapshot["activity"].(map[string]interface{}); ok {
		activity := &ActivityInfo{}
		if val, ok := activityData["label"].(string); ok {
			activity.Label = val
		}
		snapshot.Activity = activity
	}

	return snapshot, nil
}

// recordPreviewHistory 记录预览历史
func recordPreviewHistory(ctx context.Context, userID uint64, previewToken, viewerOpenID string) {
	// 这里可以记录预览历史，用于统计和分析
	logrus.Infof("Preview history: userID=%d, token=%s, viewer=%s", userID, previewToken, viewerOpenID)
}

// sendMessage 发送消息
func sendMessage(ctx context.Context, openID, content string) error {
	client := GetClient()
	if client == nil {
		return fmt.Errorf("lark client not initialized")
	}

	req := larkim.NewCreateMessageReqBuilder().
		ReceiveIdType("open_id").
		Body(larkim.NewCreateMessageReqBodyBuilder().
			ReceiveId(openID).
			MsgType("text").
			Content(fmt.Sprintf(`{"text":"%s"}`, content)).
			Uuid(fmt.Sprintf("%d", time.Now().UnixNano())).
			Build()).
		Build()

	_, err := client.Im.Message.Create(ctx, req)
	if err != nil {
		logrus.Errorf("Failed to send message: %v", err)
		return err
	}

	return nil
}
