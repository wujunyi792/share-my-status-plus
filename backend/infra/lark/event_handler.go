package lark

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"share-my-status/domain/render"
	"share-my-status/domain/user"
	"share-my-status/infra/config"
	"share-my-status/model"
	"share-my-status/pkg/crypto"
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
	userService   *user.UserService
	larkClient    *lark.Client
	config        *config.Config
	renderService *render.Service
}

// NewEventHandler 创建事件处理器
func NewEventHandler(userService *user.UserService, larkClient *lark.Client, cfg *config.Config, renderService *render.Service) *EventHandler {
	return &EventHandler{userService: userService, larkClient: larkClient, config: cfg, renderService: renderService}
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
				return h.replyInteractiveMessage(ctx, messageID, buildUserErrorCard("账户初始化失败", err))
			}
		} else {
			logrus.Errorf("Failed to get user: %v", err)
			return h.replyInteractiveMessage(ctx, messageID, buildUserErrorCard("账户读取失败", err))
		}
	}

	// 执行命令
	response, err := h.executeCommand(ctx, user, command)
	if err != nil {
		logrus.Errorf("Failed to execute command: %v", err)
		return h.replyInteractiveMessage(ctx, messageID, buildExecErrorCard(err))
	}

	return h.replyCommandResponse(ctx, messageID, response)
}

// OnP2CardURLPreviewGet 处理链接预览事件
func (h *EventHandler) OnP2CardURLPreviewGet(ctx context.Context, event *callback.URLPreviewGetEvent) (*callback.URLPreviewGetResponse, error) {
	logrus.Infof("URL preview request: %s", event.Event.Context.URL)

	urlPreview := toLarkURLPreview(render.NewDefaultPreview())

	// 解析URL
	parsedURL, err := url.Parse(event.Event.Context.URL)
	if err != nil {
		logrus.Errorf("Failed to parse URL: %v", err)
		return urlPreview, nil
	}

	// 提取参数
	key := h.extractSharingKey(parsedURL.Path)
	template := parsedURL.Query().Get("m")
	if template == "" {
		template = render.DefaultTemplate
	}

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

		u, err := h.userService.GetUserByOpenID(key)
		if err != nil {
			logrus.Errorf("Failed to get user by open id: %v", err)
			return urlPreview, nil
		}

		preview, err := h.renderService.RenderByUserID(ctx, u.ID, template)
		if err != nil {
			return handleURLPreviewRenderError(urlPreview, err), nil
		}
		return toLarkURLPreview(preview), nil
	}

	preview, err := h.renderService.RenderBySharingKey(ctx, key, template)
	if err != nil {
		return handleURLPreviewRenderError(urlPreview, err), nil
	}

	return toLarkURLPreview(preview), nil
}

func handleURLPreviewRenderError(urlPreview *callback.URLPreviewGetResponse, err error) *callback.URLPreviewGetResponse {
	switch {
	case errors.Is(err, render.ErrPublicAccessDisabled):
		urlPreview.Inline.Title = "未开启公开访问"
	case errors.Is(err, render.ErrSharingKeyNotFound):
		logrus.Errorf("Failed to get user by sharing key: %v", err)
	default:
		logrus.Errorf("Failed to render URL preview: %v", err)
	}
	return urlPreview
}

func toLarkURLPreview(preview *render.PreviewResponse) *callback.URLPreviewGetResponse {
	resp := &callback.URLPreviewGetResponse{}
	if preview == nil || preview.Inline == nil {
		return resp
	}

	resp.Inline = &callback.Inline{
		Title:     preview.Inline.Title,
		I18nTitle: preview.Inline.I18nTitle,
		ImageKey:  preview.Inline.ImageKey,
	}
	if preview.Inline.URL != nil {
		resp.Inline.URL = &callback.URL{
			CopyURL: preview.Inline.URL.CopyURL,
			IOS:     preview.Inline.URL.IOS,
			Android: preview.Inline.URL.Android,
			PC:      preview.Inline.URL.PC,
			Web:     preview.Inline.URL.Web,
		}
	}

	return resp
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
		"开启公开访问":        {Action: "public", Params: []string{"on"}},
		"关闭公开访问":        {Action: "public", Params: []string{"off"}},
		"授权音乐统计":        {Action: "stat", Params: []string{"on"}},
		"取消授权音乐统计":      {Action: "stat", Params: []string{"off"}},
		"查看我的信息":        {Action: "info", Params: []string{}},
		"轮转数据上报密钥":      {Action: "rotate", Params: []string{"secret-key"}},
		"轮转个人主页/飞书签名链接": {Action: "rotate", Params: []string{"sharing-key"}},
		"轮转个人主页":        {Action: "rotate", Params: []string{"sharing-key"}},
		"帮助":            {Action: "help", Params: []string{}},
		"推荐配置":          {Action: "config", Params: []string{}},
	}

	if cmd, ok := alias[text]; ok {
		return cmd
	}

	return &Command{Action: "unknown", Params: []string{}}
}

// executeCommand 执行命令
func (h *EventHandler) executeCommand(ctx context.Context, user *model.User, command *Command) (*commandResponse, error) {
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
	case "config":
		if len(command.Params) != 0 {
			return cardResponse(buildParamErrorCard([]string{"/config"}, "/config")), nil
		}
		configJSON := h.buildRecommendedConfigJSON(user, &h.config.App)
		return cardResponse(buildConfigCard(configJSON, user, &h.config.App)), nil
	case "help":
		if len(command.Params) != 0 {
			return cardResponse(buildParamErrorCard([]string{"/help"}, "/help")), nil
		}
		return cardResponse(buildHelpCard()), nil
	default:
		return cardResponse(buildUnknownCommandCard()), nil
	}
}

// executePublicCommand 执行公开访问命令
func (h *EventHandler) executePublicCommand(ctx context.Context, user *model.User, userService *user.UserService, params []string) (*commandResponse, error) {
	if len(params) != 1 {
		return cardResponse(buildParamErrorCard([]string{"/public on", "/public off"}, "/public on")), nil
	}

	var enable bool
	switch params[0] {
	case "on":
		enable = true
	case "off":
		enable = false
	default:
		return cardResponse(buildParamErrorCard([]string{"/public on", "/public off"}, "/public on")), nil
	}

	// 获取当前设置
	settings, err := userService.GetUserSettings(user.ID)
	if err != nil && err != gorm.ErrRecordNotFound {
		return nil, fmt.Errorf("failed to get user settings: %w", err)
	}

	// 更新设置
	var newSettings model.UserSettingsPayload
	if settings != nil {
		newSettings = settings.Settings.Data()
	}
	newSettings.PublicEnabled = enable

	err = userService.UpdateUserSettings(user.ID, newSettings)
	if err != nil {
		return nil, fmt.Errorf("failed to update settings: %w", err)
	}

	return cardResponse(buildPublicStatusCard(enable, &h.config.App, user.SharingKey)), nil
}

// executeStatCommand 执行音乐统计授权命令
func (h *EventHandler) executeStatCommand(ctx context.Context, user *model.User, userService *user.UserService, params []string) (*commandResponse, error) {
	if len(params) != 1 {
		return cardResponse(buildParamErrorCard([]string{"/stat on", "/stat off"}, "/stat on")), nil
	}

	var enable bool
	switch params[0] {
	case "on":
		enable = true
	case "off":
		enable = false
	default:
		return cardResponse(buildParamErrorCard([]string{"/stat on", "/stat off"}, "/stat on")), nil
	}

	// 获取当前设置
	settings, err := userService.GetUserSettings(user.ID)
	if err != nil && err != gorm.ErrRecordNotFound {
		return nil, fmt.Errorf("failed to get user settings: %w", err)
	}

	// 更新设置
	var newSettings model.UserSettingsPayload
	if settings != nil {
		newSettings = settings.Settings.Data()
	}
	newSettings.AuthorizedMusicStats = enable

	err = userService.UpdateUserSettings(user.ID, newSettings)
	if err != nil {
		return nil, fmt.Errorf("failed to update settings: %w", err)
	}

	return cardResponse(buildStatStatusCard(enable, &h.config.App, user.SharingKey)), nil
}

// executeRotateCommand 执行轮转命令
func (h *EventHandler) executeRotateCommand(ctx context.Context, user *model.User, userService *user.UserService, params []string) (*commandResponse, error) {
	if len(params) != 1 {
		return cardResponse(buildParamErrorCard([]string{"/rotate secret-key", "/rotate sharing-key"}, "/rotate secret-key")), nil
	}

	keyType := params[0]

	switch keyType {
	case "secret-key":
		// 生成新的Secret Key
		newSecretKey, err := userService.RotateSecretKey(user.ID)
		if err != nil {
			return nil, fmt.Errorf("failed to rotate secret key: %w", err)
		}
		return cardResponse(buildRotateSecretCard(newSecretKey, &h.config.App)), nil

	case "sharing-key":
		// 生成新的Sharing Key
		newSharingKey, err := userService.RotateSharingKey(user.ID)
		if err != nil {
			return nil, fmt.Errorf("failed to rotate sharing key: %w", err)
		}
		return cardResponse(buildRotateSharingCard(newSharingKey, &h.config.App)), nil
	default:
		return cardResponse(buildParamErrorCard([]string{"/rotate secret-key", "/rotate sharing-key"}, "/rotate secret-key")), nil
	}
}

// executeInfoCommand 执行信息命令
func (h *EventHandler) executeInfoCommand(ctx context.Context, user *model.User, userService *user.UserService) (*commandResponse, error) {
	// 获取用户设置
	settings, err := userService.GetUserSettings(user.ID)
	if err != nil && err != gorm.ErrRecordNotFound {
		return nil, fmt.Errorf("failed to get user settings: %w", err)
	}

	publicEnabled := false
	musicStatsAuthorized := false
	if settings != nil {
		publicEnabled = settings.Settings.Data().PublicEnabled
		musicStatsAuthorized = settings.Settings.Data().AuthorizedMusicStats
	}

	return cardResponse(buildAccountInfoCard(user, &h.config.App, publicEnabled, musicStatsAuthorized)), nil
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

// replyCommandResponse 回复结构化命令结果
func (h *EventHandler) replyCommandResponse(ctx context.Context, messageID string, response *commandResponse) error {
	if response == nil {
		return nil
	}
	switch response.msgType {
	case msgTypeInteractive:
		return h.replyInteractiveMessage(ctx, messageID, response.card)
	default:
		return h.replyMessage(ctx, messageID, response.text)
	}
}

// replyInteractiveMessage 回复飞书交互式卡片
func (h *EventHandler) replyInteractiveMessage(ctx context.Context, messageID string, card map[string]any) error {
	client := h.larkClient
	if client == nil {
		return fmt.Errorf("lark client not initialized")
	}

	data, err := json.Marshal(card)
	if err != nil {
		logrus.Errorf("Failed to marshal interactive card: %v", err)
		return err
	}

	req := larkim.NewReplyMessageReqBuilder().
		MessageId(messageID).
		Body(larkim.NewReplyMessageReqBodyBuilder().
			MsgType(msgTypeInteractive).
			Content(string(data)).
			Uuid(fmt.Sprintf("%d", time.Now().UnixNano())).
			Build()).
		Build()

	_, err = client.Im.Message.Reply(ctx, req)
	if err != nil {
		logrus.Errorf("Failed to send interactive card: %v", err)
		return err
	}

	return nil
}

// 构建推荐配置 JSON(单份配置,各平台客户端各取所需)。
//
// 一个活动分组同时带 macOS 的 bundleId(字段 "bundleIds")和 Windows 的进程 exe 名
// (字段 "processNames"):macOS 客户端只解 "bundleIds"、Windows 只解 "processNames",
// 各自忽略对方字段(Swift Codable 与 System.Text.Json 默认都忽略未知键)。音乐白名单
// 下发空数组:macOS 视作"允许所有播放器",Windows 已彻底移除该字段会直接忽略。这样
// 一条 /config 同时适配两端,用户不必区分平台。
func (h *EventHandler) buildRecommendedConfigJSON(user *model.User, cfg *config.AppConfig) string {
	config := map[string]any{
		"activityGroups":           unifiedActivityGroups(),
		"activityPollingInterval":  5,
		"activityReportingEnabled": false,
		"endpointURL":              cfg.Endpoint + "/api/v1/state/report",
		"isReportingEnabled":       true,
		"musicAppWhitelist":        []string{}, // 空 = 允许所有播放器(macOS);Windows 忽略此字段
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

// 合并 macOS / Windows 默认分组为单份配置:同名分组各带 bundleIds + processNames。
// 两端默认分组同名同序(见客户端 DefaultSettings),按名归并。
func unifiedActivityGroups() []map[string]any {
	winByName := make(map[string][]string)
	for _, g := range windowsActivityGroups() {
		winByName[g["name"].(string)] = g["processNames"].([]string)
	}

	macGroups := macActivityGroups()
	out := make([]map[string]any, 0, len(macGroups))
	for _, g := range macGroups {
		name := g["name"].(string)
		procs := winByName[name]
		if procs == nil {
			procs = []string{}
		}
		out = append(out, map[string]any{
			"name":         name,
			"isEnabled":    true,
			"bundleIds":    g["bundleIds"],
			"processNames": procs,
		})
	}
	return out
}

// macOS 推荐活动分组(bundleId)。需与客户端 DefaultSettings.swift 保持一致。
func macActivityGroups() []map[string]any {
	return []map[string]any{
		{"name": "在工作&研究", "isEnabled": true, "bundleIds": []string{
			"com.apple.iWork.Pages", "com.apple.iWork.Numbers", "com.apple.iWork.Keynote",
			"com.microsoft.Word", "com.microsoft.Excel", "com.microsoft.Powerpoint",
			"com.microsoft.onenote.mac", "com.microsoft.Outlook", "com.microsoft.teams",
			"com.electron.lark", "com.volcengine.corplink", "com.raycast.macos",
			"com.share-my-status.client", "cn.trae.app", "com.trae.app", "com.microsoft.OneDrive",
		}},
		{"name": "在搞研发", "isEnabled": true, "bundleIds": []string{
			"com.microsoft.VSCode", "com.sublimetext.3", "com.apple.dt.Xcode",
			"com.SweetScape.010Editor", "me.qii404.another-redis-desktop-manager", "cn.apifox.app",
			"com.todesktop.230313mzl4w4u92", "com.jetbrains.goland", "com.jetbrains.toolbox",
			"com.mongodb.compass", "com.electron.ollama", "io.podmandesktop.PodmanDesktop",
			"com.postmanlabs.mac",
		}},
		{"name": "在设计", "isEnabled": true, "bundleIds": []string{
			"com.bohemiancoding.sketch3", "com.figma.Desktop", "com.adobe.Photoshop",
		}},
		{"name": "在开会", "isEnabled": true, "bundleIds": []string{
			"us.zoom.xos", "com.tinyspeck.slackmacgap",
		}},
		{"name": "在浏览", "isEnabled": true, "bundleIds": []string{
			"com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox", "com.brave.Browser",
			"com.operasoftware.Opera", "company.thebrowser.Browser", "com.microsoft.edgemac",
			"com.vivaldi.Vivaldi",
		}},
		{"name": "在终端", "isEnabled": true, "bundleIds": []string{
			"com.apple.Terminal", "com.googlecode.iterm2", "com.googlecode.iterm2.iTermAI",
			"com.termius-dmg.mac",
		}},
		{"name": "在娱乐", "isEnabled": true, "bundleIds": []string{
			"com.bytedance.douyin.desktop", "com.soda.music", "com.xingin.discover",
			"com.meituan.imovie", "com.netease.163music", "com.tencent.QQMusicMac",
		}},
		{"name": "在社交", "isEnabled": true, "bundleIds": []string{
			"com.apple.iChat", "com.tencent.xinWeChat", "com.apple.MobileSMS",
			"com.apple.facetime", "com.apple.Messages", "com.tencent.qq",
		}},
	}
}

// Windows 推荐活动分组(进程 exe 名)。需与客户端 DefaultSettings.cs 保持一致。
func windowsActivityGroups() []map[string]any {
	return []map[string]any{
		{"name": "在工作&研究", "isEnabled": true, "processNames": []string{
			"winword.exe", "excel.exe", "powerpnt.exe", "onenote.exe", "onenotem.exe",
			"outlook.exe", "msaccess.exe", "mspub.exe", "visio.exe", "winproj.exe",
			"wps.exe", "et.exe", "wpp.exe", "wpscloudsvr.exe", "pdfpro.exe",
			"acrobat.exe", "acrord32.exe", "foxitpdfreader.exe", "foxit reader.exe", "sumatrapdf.exe",
			"feishu.exe", "lark.exe", "dingtalk.exe", "wxwork.exe", "wework.exe",
			"ms-teams.exe", "teams.exe", "lync.exe", "corplink.exe", "sunloginclient.exe", "todesk.exe",
			"notion.exe", "obsidian.exe", "logseq.exe", "typora.exe", "evernote.exe",
			"youdaonote.exe", "wiznote.exe", "joplin.exe", "anytype.exe", "siyuan.exe",
			"onedrive.exe", "googledrivefs.exe", "dropbox.exe", "baidunetdisk.exe", "alipan.exe",
		}},
		{"name": "在搞研发", "isEnabled": true, "processNames": []string{
			"code.exe", "code - insiders.exe", "cursor.exe", "trae.exe", "windsurf.exe",
			"zed.exe", "devenv.exe", "rider64.exe", "idea64.exe", "goland64.exe",
			"pycharm64.exe", "webstorm64.exe", "clion64.exe", "phpstorm64.exe",
			"rubymine64.exe", "rustrover64.exe", "datagrip64.exe", "studio64.exe",
			"sublime_text.exe", "notepad++.exe", "atom.exe", "010editor.exe", "fleet.exe",
			"postman.exe", "apifox.exe", "insomnia.exe", "bruno.exe",
			"another redis desktop manager.exe", "anotherredisdesktopmanager.exe",
			"redisinsight.exe", "compass.exe", "navicat.exe", "dbeaver.exe", "heidisql.exe",
			"tableplus.exe", "fiddler.exe", "fiddler everywhere.exe", "charles.exe", "wireshark.exe",
			"docker desktop.exe", "podman desktop.exe", "rancher desktop.exe",
			"gitkraken.exe", "sourcetree.exe", "fork.exe", "github desktop.exe",
			"tortoisegitproc.exe", "ollama.exe", "ollama app.exe", "lm studio.exe",
		}},
		{"name": "在设计", "isEnabled": true, "processNames": []string{
			"photoshop.exe", "illustrator.exe", "afterfx.exe", "adobe premiere pro.exe",
			"lightroom.exe", "acrobat.exe", "figma.exe", "xd.exe", "adobe xd.exe",
			"afdesign.exe", "afphoto.exe", "afpub.exe", "blender.exe", "sketchup.exe",
			"coreldrw.exe", "axure.exe", "pixso.exe", "mastergo.exe", "cad.exe", "acad.exe",
		}},
		{"name": "在开会", "isEnabled": true, "processNames": []string{
			"zoom.exe", "webex.exe", "atmgr.exe", "voov.exe", "wemeetapp.exe",
			"feishumeeting.exe", "classin.exe", "gotomeeting.exe", "bluejeans.exe",
		}},
		{"name": "在浏览", "isEnabled": true, "processNames": []string{
			"chrome.exe", "msedge.exe", "firefox.exe", "brave.exe", "opera.exe",
			"vivaldi.exe", "arc.exe", "chromium.exe", "thorium.exe", "librewolf.exe",
			"floorp.exe", "zen.exe", "360se.exe", "360chromex.exe", "qqbrowser.exe",
			"sogouexplorer.exe", "maxthon.exe", "ucbrowser.exe", "tor browser.exe", "dragon.exe",
		}},
		{"name": "在终端", "isEnabled": true, "processNames": []string{
			"windowsterminal.exe", "wt.exe", "powershell.exe", "pwsh.exe", "cmd.exe",
			"mintty.exe", "alacritty.exe", "wezterm-gui.exe", "conemu64.exe", "hyper.exe",
			"tabby.exe", "putty.exe", "kitty.exe", "mobaxterm.exe", "xshell.exe",
			"securecrt.exe", "termius.exe", "finalshell.exe", "warp.exe",
		}},
		{"name": "在娱乐", "isEnabled": true, "processNames": []string{
			"spotify.exe", "cloudmusic.exe", "qqmusic.exe", "kugou.exe", "kuwo.exe",
			"applemusic.exe", "aimp.exe", "musicbee.exe", "foobar2000.exe",
			"bilibili.exe", "douyin.exe", "potplayermini64.exe", "potplayermini.exe",
			"vlc.exe", "mpv.exe", "mpc-hc64.exe", "kmplayer.exe", "qqlive.exe",
			"qyclient.exe", "youku.exe", "miguvideo.exe", "netflix.exe",
			"steam.exe", "epicgameslauncher.exe", "wegame.exe", "battle.net.exe",
			"obs64.exe", "obs32.exe",
		}},
		{"name": "在社交", "isEnabled": true, "processNames": []string{
			"qq.exe", "tim.exe", "weixin.exe", "wechat.exe", "telegram.exe",
			"discord.exe", "whatsapp.exe", "messenger.exe", "skype.exe", "signal.exe",
			"line.exe", "kakaotalk.exe", "viber.exe", "slack.exe", "element.exe", "zalo.exe",
		}},
	}
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
