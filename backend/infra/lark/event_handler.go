package lark

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"share-my-status/api/model/share_my_status/common"
	"share-my-status/domain/user"
	"share-my-status/infra/config"
	"share-my-status/model"
	"share-my-status/pkg/dbutil"
	"strings"
	"time"

	lark "github.com/larksuite/oapi-sdk-go/v3"
	"github.com/larksuite/oapi-sdk-go/v3/event/dispatcher/callback"
	larkim "github.com/larksuite/oapi-sdk-go/v3/service/im/v1"
	"github.com/sirupsen/logrus"
	"github.com/tidwall/gjson"
	"gorm.io/gorm"
)

type EventHandler struct {
	userService *user.UserService
	db          *gorm.DB
	larkClient  *lark.Client
	config      *config.Config
}

// NewEventHandler 创建事件处理器
func NewEventHandler(userService *user.UserService, db *gorm.DB, larkClient *lark.Client, cfg *config.Config) *EventHandler {
	return &EventHandler{userService: userService, db: db, larkClient: larkClient, config: cfg}
}

// OnP2MessageReceiveV1 处理飞书消息接收事件
func (h *EventHandler) OnP2MessageReceiveV1(ctx context.Context, event *larkim.P2MessageReceiveV1) error {
	openID := *event.Event.Sender.SenderId.OpenId
	messageID := *event.Event.Message.MessageId
	message := ""
	if event.Event.Message.Content != nil {
		message = *event.Event.Message.Content
	}

	logrus.Infof("Received message from user %s: %s", openID, message)

	// 解析命令
	command := h.parseCommand(message)
	if command == nil {
		return nil // 忽略非命令消息
	}

	// 获取或创建用户
	userService := h.userService
	user, err := userService.GetUserByOpenID(openID)
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			// 创建新用户
			user, err = userService.CreateUser(openID)
			if err != nil {
				logrus.Errorf("Failed to create user: %v", err)
				return h.replyMessage(ctx, messageID, "❌ 创建用户失败，请稍后重试")
			}
		} else {
			logrus.Errorf("Failed to get user: %v", err)
			return h.replyMessage(ctx, messageID, "❌ 获取用户信息失败")
		}
	}

	// 执行命令
	response, err := h.executeCommand(ctx, user, command)
	if err != nil {
		logrus.Errorf("Failed to execute command: %v", err)
		return h.replyMessage(ctx, messageID, fmt.Sprintf("❌ 执行命令失败: %v", err))
	}

	return h.replyMessage(ctx, messageID, response)
}

// OnP2CardURLPreviewGet 处理链接预览事件
func (h *EventHandler) OnP2CardURLPreviewGet(ctx context.Context, event *callback.URLPreviewGetEvent) (*callback.URLPreviewGetResponse, error) {
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
	sharingKey := h.extractSharingKey(parsedURL.Path)
	template := parsedURL.Query().Get("m")
	if template == "" {
		template = "{artist}的{title}"
	}

	if sharingKey == "" {
		logrus.Warn("No sharing key found in URL")
		return urlPreview, nil
	}

	// 获取用户状态
	userService := h.userService
	user, err := userService.GetUserBySharingKey(sharingKey)
	if err != nil {
		logrus.Errorf("Failed to get user by sharing key: %v", err)
		return urlPreview, nil
	}

	// 检查公开访问权限
	publicEnabled, err := userService.IsPublicEnabled(user.ID)
	if err != nil {
		logrus.Errorf("Failed to check public access: %v", err)
		return urlPreview, nil
	}

	if !publicEnabled {
		urlPreview.Inline.Title = "未开启公开访问"
		return urlPreview, nil
	}

	// 获取当前状态
	currentState, err := h.getCurrentState(ctx, user.ID)
	if err != nil {
		logrus.Errorf("Failed to get current state: %v", err)
		return urlPreview, nil
	}

	// 渲染模板
	title := h.renderTemplate(template, currentState)
	urlPreview.Inline.Title = title

	// 如果有封面，设置封面图片
	if currentState.Music != nil && currentState.Music.CoverHash != nil {
		// 这里应该设置实际的封面图片，暂时使用默认图片
		// urlPreview.Inline.ImageKey = getCoverImageKey(*currentState.Music.CoverHash)
	}

	// 记录预览历史
	if event.Event.Context.PreviewToken != "" {
		h.recordPreviewHistory(ctx, user.ID, event.Event.Context.PreviewToken, event.Event.Operator.OpenID)
	}

	return urlPreview, nil
}

// Command 命令结构
type Command struct {
	Action string
	Params []string
}

// parseCommand 解析命令
func (h *EventHandler) parseCommand(message string) *Command {
	message = strings.TrimSpace(gjson.Get(message, "text").String())

	parts := strings.Fields(message)
	if len(parts) < 1 {
		return nil
	}

	// 移除前缀斜杠
	action := strings.TrimPrefix(parts[0], "/")

	return &Command{
		Action: action,
		Params: parts[1:],
	}
}

// executeCommand 执行命令
func (h *EventHandler) executeCommand(ctx context.Context, user *model.User, command *Command) (string, error) {
	userService := h.userService

	switch command.Action {
	case "public":
		return h.executePublicCommand(ctx, user, userService, command.Params)
	case "stat":
		return h.executeStatCommand(ctx, user, userService, command.Params)
	case "info":
		return h.executeInfoCommand(ctx, user, userService)
	case "rotate":
		return h.executeRotateCommand(ctx, user, userService, command.Params)
	default:
		return "❓ 未知命令。支持的命令：\n• `/public on` - 开启公开访问\n• `/public off` - 关闭公开访问\n• `/stat on` - 开启音乐统计授权\n• `/stat off` - 关闭音乐统计授权\n• `/info` - 查看账户信息\n• `/rotate secret-key` - 轮转客户端密钥\n• `/rotate sharing-key` - 轮转分享链接密钥", nil
	}
}

// executePublicCommand 执行公开访问命令
func (h *EventHandler) executePublicCommand(ctx context.Context, user *model.User, userService *user.UserService, params []string) (string, error) {
	if len(params) != 1 {
		return "❌ 用法错误，请使用：\n• `/public on` - 开启公开访问\n• `/public off` - 关闭公开访问", nil
	}

	enable := params[0] == "on"

	// 获取当前设置
	settings, err := userService.GetUserSettings(user.ID)
	if err != nil && err != gorm.ErrRecordNotFound {
		return "", fmt.Errorf("failed to get user settings: %w", err)
	}

	// 更新设置
	var newSettings model.UserSettingsPayload
	if settings != nil {
		newSettings = settings.Settings.Data()
	}
	newSettings.PublicEnabled = enable

	err = userService.UpdateUserSettings(user.ID, newSettings)
	if err != nil {
		return "", fmt.Errorf("failed to update settings: %w", err)
	}

	status := "✅ 公开访问已关闭"
	if enable {
		sharingURL := h.buildSharingURL(user.SharingKey)
		status = fmt.Sprintf("✅ 公开访问已开启\n🔗 分享链接: %s", sharingURL)
	}

	return status, nil
}

// executeStatCommand 执行音乐统计授权命令
func (h *EventHandler) executeStatCommand(ctx context.Context, user *model.User, userService *user.UserService, params []string) (string, error) {
	if len(params) != 1 {
		return "❌ 用法错误，请使用：\n• `/stat on` - 开启音乐统计授权\n• `/stat off` - 关闭音乐统计授权", nil
	}

	enable := params[0] == "on"

	// 获取当前设置
	settings, err := userService.GetUserSettings(user.ID)
	if err != nil && err != gorm.ErrRecordNotFound {
		return "", fmt.Errorf("failed to get user settings: %w", err)
	}

	// 更新设置
	var newSettings model.UserSettingsPayload
	if settings != nil {
		newSettings = settings.Settings.Data()
	}
	newSettings.AuthorizedMusicStats = enable

	err = userService.UpdateUserSettings(user.ID, newSettings)
	if err != nil {
		return "", fmt.Errorf("failed to update settings: %w", err)
	}

	status := "关闭"
	if enable {
		status = "开启"
	}

	return fmt.Sprintf("✅ 音乐统计授权已%s", status), nil
}

// executeRotateCommand 执行轮转命令
func (h *EventHandler) executeRotateCommand(ctx context.Context, user *model.User, userService *user.UserService, params []string) (string, error) {
	if len(params) != 1 {
		return "❌ 用法错误，请使用：\n• `/rotate secret-key` - 轮转客户端密钥\n• `/rotate sharing-key` - 轮转分享链接密钥", nil
	}

	keyType := params[0]

	switch keyType {
	case "secret-key":
		// 生成新的Secret Key
		newSecretKey, err := userService.RotateSecretKey(user.ID)
		if err != nil {
			return "", fmt.Errorf("failed to rotate secret key: %w", err)
		}
		return fmt.Sprintf("✅ Secret Key已轮转\n🔑 新密钥: %s\n⚠️ 请更新客户端配置", newSecretKey), nil

	case "sharing-key":
		// 生成新的Sharing Key
		newSharingKey, err := userService.RotateSharingKey(user.ID)
		if err != nil {
			return "", fmt.Errorf("failed to rotate sharing key: %w", err)
		}
		sharingURL := h.buildSharingURL(newSharingKey)
		return fmt.Sprintf("✅ Sharing Key已轮转\n🔗 新链接: %s\n⚠️ 请更新您的分享链接", sharingURL), nil

	default:
		return "❌ 无效的密钥类型，请使用：\n• `/rotate secret-key` - 轮转客户端密钥\n• `/rotate sharing-key` - 轮转分享链接密钥", nil
	}
}

// executeInfoCommand 执行信息命令
func (h *EventHandler) executeInfoCommand(ctx context.Context, user *model.User, userService *user.UserService) (string, error) {
	// 获取用户设置
	settings, err := userService.GetUserSettings(user.ID)
	if err != nil && err != gorm.ErrRecordNotFound {
		return "", fmt.Errorf("failed to get user settings: %w", err)
	}

	publicEnabled := false
	musicStatsAuthorized := false
	if settings != nil {
		publicEnabled = settings.Settings.Data().PublicEnabled
		musicStatsAuthorized = settings.Settings.Data().AuthorizedMusicStats
	}

	// 获取当前状态
	currentState, err := h.getCurrentState(ctx, user.ID)
	if err != nil {
		logrus.Errorf("Failed to get current state: %v", err)
	}

	status := "未在播放"
	if currentState != nil && currentState.Music != nil {
		if currentState.Music.Title != nil && currentState.Music.Artist != nil {
			status = fmt.Sprintf("%s - %s", *currentState.Music.Artist, *currentState.Music.Title)
		}
	}

	sharingURL := h.buildSharingURL(user.SharingKey)
	info := fmt.Sprintf("📊 账户信息\n"+
		"🎵 当前状态: %s\n"+
		"🔑 Secret Key: %s\n"+
		"🔗 Sharing Key: %s\n"+
		"🌐 公开访问: %s\n"+
		"📈 音乐统计: %s\n"+
		"🔗 分享链接: %s",
		status,
		"[已加密存储]", // Secret Key 不直接显示
		user.SharingKey,
		map[bool]string{true: "开启", false: "关闭"}[publicEnabled],
		map[bool]string{true: "已授权", false: "未授权"}[musicStatsAuthorized],
		sharingURL)

	return info, nil
}

// extractSharingKey 从URL路径中提取Sharing Key
func (h *EventHandler) extractSharingKey(path string) string {
	// 假设路径格式为 /s/{sharingKey}
	parts := strings.Split(strings.Trim(path, "/"), "/")
	if len(parts) >= 2 && parts[0] == "s" {
		return parts[1]
	}
	return ""
}

// buildSharingURL 生成分享链接，使用配置中的DefaultTarget
func (h *EventHandler) buildSharingURL(sharingKey string) string {
	// Replace {SharingKey} placeholder with actual sharing key
	return strings.ReplaceAll(h.config.Redirect.DefaultTarget, "{SharingKey}", sharingKey)
}

// renderTemplate 渲染模板
func (h *EventHandler) renderTemplate(template string, state *common.StatusSnapshot) string {
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

// getCurrentState 获取当前状态
func (h *EventHandler) getCurrentState(ctx context.Context, userID uint64) (*common.StatusSnapshot, error) {
	return dbutil.GetCurrentStateFromDB(ctx, h.db, userID)
}

// recordPreviewHistory 记录预览历史
func (h *EventHandler) recordPreviewHistory(ctx context.Context, userID uint64, previewToken, viewerOpenID string) {
	// 这里可以记录预览历史，用于统计和分析
	logrus.Infof("Preview history: userID=%d, token=%s, viewer=%s", userID, previewToken, viewerOpenID)
}

// sendMessage 发送消息
func (h *EventHandler) sendMessage(ctx context.Context, openID, content string) error {
	client := h.larkClient
	if client == nil {
		return fmt.Errorf("lark client not initialized")
	}

	data, _ := json.Marshal(map[string]string{
		"text": content,
	})

	req := larkim.NewCreateMessageReqBuilder().
		ReceiveIdType("open_id").
		Body(larkim.NewCreateMessageReqBodyBuilder().
			ReceiveId(openID).
			MsgType("text").
			Content(string(data)).
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

// replyMessage 回复消息
func (h *EventHandler) replyMessage(ctx context.Context, messageID, content string) error {
	client := h.larkClient
	if client == nil {
		return fmt.Errorf("lark client not initialized")
	}

	data, _ := json.Marshal(map[string]string{
		"text": content,
	})

	req := larkim.NewReplyMessageReqBuilder().
		MessageId(messageID).
		Body(larkim.NewReplyMessageReqBodyBuilder().
			MsgType("text").
			Content(string(data)).
			Uuid(fmt.Sprintf("%d", time.Now().UnixNano())).
			Build()).
		Build()

	_, err := client.Im.Message.Reply(ctx, req)
	if err != nil {
		logrus.Errorf("Failed to send message: %v", err)
		return err
	}

	return nil
}
