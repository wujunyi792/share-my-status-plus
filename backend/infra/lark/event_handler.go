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
	"share-my-status/pkg/crypto"
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

	// 特殊命令：/config 或 推荐配置 使用富文本(Post)回复
	if command.Action == "config" && len(command.Params) == 0 {
		cfgJSON := h.buildRecommendedConfigJSON(user, &h.config.App)

		var content [][]map[string]any
		content = append(content, []map[string]any{
			{"tag": "code_block", "language": "JSON", "text": cfgJSON},
		})

		post := map[string]any{
			"zh_cn": map[string]any{
				"title":   "推荐配置",
				"content": content,
			},
		}

		return h.replyPostMessage(ctx, messageID, post)
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
	key := h.extractSharingKey(parsedURL.Path)
	var fn func(id string) (*model.User, error)
	if key == "" {
		// 旧版兼容
		openIDEncoded := parsedURL.Query().Get("u")
		if openIDEncoded == "" {
			return urlPreview, nil
		}
		key, err = crypto.Decode(openIDEncoded, h.config.LegacyCrypto.Key, h.config.LegacyCrypto.IV)
		if err != nil {
			logrus.Errorf("Failed to decode openID: %v", err)
			return urlPreview, nil
		}
		fn = h.userService.GetUserByOpenID
	} else {
		fn = h.userService.GetUserBySharingKey
	}

	if key == "" {
		logrus.Warn("No sharing key found in URL")
		return urlPreview, nil
	}

	template := parsedURL.Query().Get("m")
	if template == "" {
		template = "正在听{artist}-{title}"
	}

	// 获取用户状态
	u, err := fn(key)
	if err != nil {
		logrus.Errorf("Failed to get user by sharing key: %v", err)
		return urlPreview, nil
	}

	// 检查公开访问权限
	publicEnabled, err := h.userService.IsPublicEnabled(u.ID)
	if err != nil {
		logrus.Errorf("Failed to check public access: %v", err)
		return urlPreview, nil
	}

	if !publicEnabled {
		urlPreview.Inline.Title = "未开启公开访问"
		return urlPreview, nil
	}

	// 获取当前状态
	currentState, err := h.getCurrentState(ctx, u.ID)
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

	return urlPreview, nil
}

// Command 命令结构
type Command struct {
	Action string
	Params []string
}

// parseCommand 解析命令
func (h *EventHandler) parseCommand(message string) *Command {
	text := strings.TrimSpace(gjson.Get(message, "text").String())
	if text == "" {
		return nil
	}

	lower := strings.ToLower(text)

	// 以斜杠开头的命令（例如 /public on）
	if strings.HasPrefix(text, "/") {
		parts := strings.Fields(lower)
		if len(parts) < 1 {
			return nil
		}
		action := strings.TrimPrefix(parts[0], "/")
		return &Command{Action: action, Params: parts[1:]}
	}

	// 中文别名命令映射
	alias := map[string]*Command{
		"开启公开访问":   {Action: "public", Params: []string{"on"}},
		"关闭公开访问":   {Action: "public", Params: []string{"off"}},
		"授权音乐统计":   {Action: "stat", Params: []string{"on"}},
		"取消授权音乐统计": {Action: "stat", Params: []string{"off"}},
		"查看我的信息":   {Action: "info", Params: []string{}},
		"轮转数据上报密钥": {Action: "rotate", Params: []string{"secret-key"}},
		"轮转分享链接":   {Action: "rotate", Params: []string{"sharing-key"}},
		"帮助":       {Action: "help", Params: []string{}},
		"推荐配置":     {Action: "config", Params: []string{}},
	}

	if cmd, ok := alias[text]; ok {
		return cmd
	}

	// 英文 help
	if lower == "help" {
		return &Command{Action: "help", Params: []string{}}
	}

	return nil
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
	case "help":
		return "ℹ️ 帮助：\n• `/public on` - 开启公开访问\n• `/public off` - 关闭公开访问\n• `/stat on` - 授权音乐统计\n• `/stat off` - 取消授权音乐统计\n• `/info` - 查看我的信息\n• `/rotate secret-key` - 轮转数据上报密钥\n• `/rotate sharing-key` - 轮转分享链接\n• `/config` - 返回推荐配置 JSON\n• `/help` - 帮助\n\n中文别名也支持：\n• 开启公开访问\n• 关闭公开访问\n• 授权音乐统计\n• 取消授权音乐统计\n• 查看我的信息\n• 轮转数据上报密钥\n• 轮转分享链接\n• 推荐配置\n• 帮助", nil
	default:
		return "❓ 未知命令。支持的命令：\n• `/public on` - 开启公开访问\n• `/public off` - 关闭公开访问\n• `/stat on` - 授权音乐统计\n• `/stat off` - 取消授权音乐统计\n• `/info` - 查看我的信息\n• `/rotate secret-key` - 轮转数据上报密钥\n• `/rotate sharing-key` - 轮转分享链接\n• `/config` - 返回推荐配置 JSON\n• `/help` - 帮助\n\n中文别名也支持：\n• 开启公开访问\n• 关闭公开访问\n• 授权音乐统计\n• 取消授权音乐统计\n• 查看我的信息\n• 轮转数据上报密钥\n• 轮转分享链接\n• 推荐配置\n• 帮助", nil
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
		return "❌ 用法错误，请使用：\n• `/stat on` - 授权音乐统计\n• `/stat off` - 取消授权音乐统计", nil
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

	sharingURL := h.buildSharingURL(user.SharingKey)
	reportURL := h.config.App.Endpoint + "/api/v1/state/report"
	signatureURL := h.config.App.Endpoint + "/s/" + user.SharingKey
	info := fmt.Sprintf("📊 账户信息\n"+
		"🔑 Secret Key: %s\n"+
		"📮 上报地址: %s\n"+
		"✍️ 飞书签名链接: %s\n"+
		"🔗 Sharing Key: %s\n"+
		"🌐 公开访问: %s\n"+
		"📈 音乐统计: %s\n"+
		"🔗 分享链接: %s",
		user.SecretKey,
		reportURL,
		signatureURL,
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
		result = strings.ReplaceAll(result, "{album}", "")
		result = strings.ReplaceAll(result, "{activityLabel}", "")
		result = h.renderTimeVariables(result)
		result = h.renderSystemVariables(result, nil)
		result = h.renderConditionalVariables(result, nil)
		return result
	}

	result := template

	// 替换音乐信息
	result = h.renderMusicVariables(result, state.Music)

	// 替换系统信息
	result = h.renderSystemVariables(result, state.System)

	// 替换活动信息
	result = h.renderActivityVariables(result, state.Activity)

	// 替换时间信息
	result = h.renderTimeVariables(result)

	// 替换条件表达式
	result = h.renderConditionalVariables(result, state.System)

	return result
}

// getCurrentState 获取当前状态
func (h *EventHandler) getCurrentState(ctx context.Context, userID uint64) (*common.StatusSnapshot, error) {
	return dbutil.GetCurrentStateFromDB(ctx, h.db, userID)
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

// renderMusicVariables 渲染音乐相关变量
func (h *EventHandler) renderMusicVariables(template string, music *common.Music) string {
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

// renderSystemVariables 渲染系统相关变量
func (h *EventHandler) renderSystemVariables(template string, system *common.System) string {
	result := template

	if system != nil {
		// 电量百分比
		if system.BatteryPct != nil {
			batteryPct := *system.BatteryPct
			result = strings.ReplaceAll(result, "{batteryPct}", fmt.Sprintf("%.2f", batteryPct))
			result = strings.ReplaceAll(result, "{batteryPctRounded}", fmt.Sprintf("%.0f%%", batteryPct*100))
		} else {
			result = strings.ReplaceAll(result, "{batteryPct}", "")
			result = strings.ReplaceAll(result, "{batteryPctRounded}", "")
		}

		// CPU使用率
		if system.CpuPct != nil {
			cpuPct := *system.CpuPct
			result = strings.ReplaceAll(result, "{cpuPct}", fmt.Sprintf("%.2f", cpuPct))
			result = strings.ReplaceAll(result, "{cpuPctRounded}", fmt.Sprintf("%.0f%%", cpuPct*100))
		} else {
			result = strings.ReplaceAll(result, "{cpuPct}", "")
			result = strings.ReplaceAll(result, "{cpuPctRounded}", "")
		}

		// 内存使用率
		if system.MemoryPct != nil {
			memoryPct := *system.MemoryPct
			result = strings.ReplaceAll(result, "{memoryPct}", fmt.Sprintf("%.2f", memoryPct))
			result = strings.ReplaceAll(result, "{memoryPctRounded}", fmt.Sprintf("%.0f%%", memoryPct*100))
		} else {
			result = strings.ReplaceAll(result, "{memoryPct}", "")
			result = strings.ReplaceAll(result, "{memoryPctRounded}", "")
		}
	} else {
		// 清空所有系统变量
		result = strings.ReplaceAll(result, "{batteryPct}", "")
		result = strings.ReplaceAll(result, "{batteryPctRounded}", "")
		result = strings.ReplaceAll(result, "{cpuPct}", "")
		result = strings.ReplaceAll(result, "{cpuPctRounded}", "")
		result = strings.ReplaceAll(result, "{memoryPct}", "")
		result = strings.ReplaceAll(result, "{memoryPctRounded}", "")
	}

	return result
}

// renderActivityVariables 渲染活动相关变量
func (h *EventHandler) renderActivityVariables(template string, activity *common.Activity) string {
	result := template

	if activity != nil && activity.Label != "" {
		result = strings.ReplaceAll(result, "{activityLabel}", activity.Label)
	} else {
		result = strings.ReplaceAll(result, "{activityLabel}", "")
	}

	return result
}

// renderTimeVariables 渲染时间相关变量
func (h *EventHandler) renderTimeVariables(template string) string {
	result := template
	now := time.Now()

	// 本地时间
	result = strings.ReplaceAll(result, "{nowLocal}", now.Format("2006-01-02 15:04:05"))

	// 日期 (年-月-日)
	result = strings.ReplaceAll(result, "{dateYMD}", now.Format("2006-01-02"))

	// ISO 8601 格式
	result = strings.ReplaceAll(result, "{nowISO}", now.Format(time.RFC3339))

	return result
}

// renderConditionalVariables 渲染条件表达式变量
func (h *EventHandler) renderConditionalVariables(template string, system *common.System) string {
	result := template

	// 处理充电状态条件表达式 {charging?'充电中':'未充电'}
	if strings.Contains(result, "{charging?") {
		charging := false
		if system != nil && system.Charging != nil {
			charging = *system.Charging
		}

		// 简单的条件表达式解析
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

// 构建推荐配置 JSON
func (h *EventHandler) buildRecommendedConfigJSON(user *model.User, cfg *config.AppConfig) string {
	activityGroups := []map[string]any{
		{
			"bundleIds": []string{
				"com.apple.iWork.Pages",
				"com.apple.iWork.Numbers",
				"com.apple.iWork.Keynote",
				"com.microsoft.Word",
				"com.microsoft.Excel",
				"com.microsoft.Powerpoint",
				"com.microsoft.onenote.mac",
				"com.microsoft.Outlook",
				"com.microsoft.teams",
				"com.electron.lark",
				"com.volcengine.corplink",
				"com.raycast.macos",
				"com.share-my-status.client",
				"cn.trae.app",
				"com.trae.app",
				"com.microsoft.OneDrive",
			},
			"isEnabled": true,
			"name":      "在工作&研究",
		},
		{
			"bundleIds": []string{
				"com.microsoft.VSCode",
				"com.sublimetext.3",
				"com.apple.dt.Xcode",
				"com.SweetScape.010Editor",
				"me.qii404.another-redis-desktop-manager",
				"cn.apifox.app",
				"com.todesktop.230313mzl4w4u92",
				"com.jetbrains.goland",
				"com.jetbrains.toolbox",
				"com.mongodb.compass",
				"com.electron.ollama",
				"io.podmandesktop.PodmanDesktop",
				"com.postmanlabs.mac",
			},
			"isEnabled": true,
			"name":      "在搞研发",
		},
		{
			"bundleIds": []string{
				"com.bohemiancoding.sketch3",
				"com.figma.Desktop",
				"com.adobe.Photoshop",
			},
			"isEnabled": true,
			"name":      "在设计",
		},
		{
			"bundleIds": []string{
				"us.zoom.xos",
				"com.tinyspeck.slackmacgap",
			},
			"isEnabled": true,
			"name":      "在开会",
		},
		{
			"bundleIds": []string{
				"com.apple.Safari",
				"com.google.Chrome",
				"org.mozilla.firefox",
				"com.brave.Browser",
				"com.operasoftware.Opera",
				"company.thebrowser.Browser",
				"com.microsoft.edgemac",
				"com.vivaldi.Vivaldi",
			},
			"isEnabled": true,
			"name":      "在浏览",
		},
		{
			"bundleIds": []string{
				"com.apple.Terminal",
				"com.googlecode.iterm2",
				"com.googlecode.iterm2.iTermAI",
				"com.termius-dmg.mac",
			},
			"isEnabled": true,
			"name":      "在终端",
		},
		{
			"bundleIds": []string{
				"com.bytedance.douyin.desktop",
				"com.soda.music",
				"com.xingin.discover",
				"com.meituan.imovie",
				"com.netease.163music",
				"com.tencent.QQMusicMac",
			},
			"isEnabled": true,
			"name":      "在娱乐",
		},
		{
			"bundleIds": []string{
				"com.apple.iChat",
				"com.tencent.xinWeChat",
				"com.apple.MobileSMS",
				"com.apple.facetime",
				"com.apple.Messages",
				"com.tencent.qq",
			},
			"isEnabled": true,
			"name":      "在社交",
		},
	}

	musicAppWhitelist := []string{
		"com.apple.Music",
		"com.spotify.client",
		"com.netease.163music",
		"com.tencent.QQMusicMac",
		"com.soda.music",
	}

	config := map[string]any{
		"activityGroups":           activityGroups,
		"activityPollingInterval":  5,
		"activityReportingEnabled": false,
		"endpointURL":              cfg.Endpoint + "/api/v1/state/report",
		"isReportingEnabled":       true,
		"musicAppWhitelist":        musicAppWhitelist,
		"musicReportingEnabled":    true,
		"secretKey":                string(user.SecretKey),
		"systemPollingInterval":    5,
		"systemReportingEnabled":   true,
		"version":                  "1.0",
	}

	b, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		logrus.Errorf("Failed to marshal recommended config: %v", err)
		return "{}"
	}
	return string(b)
}

// 以富文本(Post)回复消息
func (h *EventHandler) replyPostMessage(ctx context.Context, messageID string, post map[string]any) error {
	client := h.larkClient
	if client == nil {
		return fmt.Errorf("lark client not initialized")
	}

	data, err := json.Marshal(post)
	if err != nil {
		logrus.Errorf("Failed to marshal post content: %v", err)
		return err
	}

	req := larkim.NewReplyMessageReqBuilder().
		MessageId(messageID).
		Body(larkim.NewReplyMessageReqBodyBuilder().
			MsgType("post").
			Content(string(data)).
			Uuid(fmt.Sprintf("%d", time.Now().UnixNano())).
			Build()).
		Build()

	_, err = client.Im.Message.Reply(ctx, req)
	if err != nil {
		logrus.Errorf("Failed to send post message: %v", err)
		return err
	}

	return nil
}
