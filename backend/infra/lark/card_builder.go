package lark

import (
	"fmt"
	"strings"

	"share-my-status/infra/config"
	"share-my-status/model"
)

const (
	msgTypeText        = "text"
	msgTypeInteractive = "interactive"
)

type commandResponse struct {
	msgType string
	text    string
	card    map[string]any
}

func textResponse(content string) *commandResponse {
	return &commandResponse{msgType: msgTypeText, text: content}
}

func cardResponse(card map[string]any) *commandResponse {
	return &commandResponse{msgType: msgTypeInteractive, card: card}
}

func buildAccountInfoCard(user *model.User, app *config.AppConfig, publicEnabled bool, musicStatsAuthorized bool) map[string]any {
	return buildBaseCard("blue", "📊 账户信息", "客户端上报与个人主页配置", "账户信息", []map[string]any{
		div([]map[string]any{
			field("🏠 个人主页", inlineOptionalURL(buildUserProfileURL(app.UserProfileURLTemplate, user.SharingKey), "USER_PROFILE_URL_TEMPLATE"), false),
			field("✍️ 飞书签名链接", inlineOptionalURL(buildSignatureURL(app.FeishuSignatureURLTemplate, user.SharingKey), "FEISHU_SIGNATURE_URL_TEMPLATE"), false),
			field("🛠 个性签名 DIY", inlineOptionalURL(buildSignatureDIYURL(app.FeishuSignatureDIYURL, user.SharingKey), "FEISHU_SIGNATURE_DIY_URL"), false),
			field("📮 上报地址", inlineCode(buildReportURL(app.Endpoint)), false),
			field("🔑 Secret Key", inlineCode(string(user.SecretKey)), false),
			field("🌐 公开访问", statusText(publicEnabled, "开启", "关闭"), true),
			field("📈 音乐统计", statusText(musicStatsAuthorized, "已授权", "未授权"), true),
			field("📘 用户文档", rawOptionalURL(app.UserDocURL, "USER_DOC_URL"), false),
		}),
		hr(),
		collapsiblePanel("📋 推荐下一步", strings.Join([]string{
			fmt.Sprintf("%s 获取客户端配置 JSON", inlineCode("/config")),
			fmt.Sprintf("%s 开启公开访问", inlineCode("/public on")),
			fmt.Sprintf("%s 授权音乐统计", inlineCode("/stat on")),
			fmt.Sprintf("%s 轮转个人主页/飞书签名链接", inlineCode("/rotate sharing-key")),
		}, "\n\n")),
		markdownWithSize("<font color='grey'>📡 Share My Status Plus</font>", "notation"),
	})
}

func buildConfigCard(configJSON string, user *model.User, app *config.AppConfig) map[string]any {
	return buildBaseCard("blue", "⚙️ 客户端配置", "复制完整 JSON 导入客户端", "客户端配置", []map[string]any{
		markdown("**推荐配置已生成**\n\n复制下面完整 JSON，粘贴到客户端设置底部的配置导入入口（macOS / Windows 通用）。"),
		hr(),
		markdown("```json\n" + configJSON + "\n```"),
		hr(),
		div([]map[string]any{
			field("📮 上报地址", inlineCode(buildReportURL(app.Endpoint)), false),
			field("🔑 Secret Key", inlineCode(string(user.SecretKey)), false),
		}),
		markdownWithSize("<font color='grey'>📡 Share My Status Plus</font>", "notation"),
	})
}

func buildHelpCard() map[string]any {
	return buildBaseCard("blue", "ℹ️ 可用命令", "账户、开关、密钥与帮助", "可用命令", []map[string]any{
		markdown("**你可以发送这些命令管理状态共享。**"),
		hr(),
		div([]map[string]any{
			field("📊 账户", inlineCode("/info")+"\n"+inlineCode("/config"), true),
			field("🌐 开关", inlineCode("/public on")+" / "+inlineCode("/public off")+"\n"+inlineCode("/stat on")+" / "+inlineCode("/stat off"), true),
			field("🔑 密钥", inlineCode("/rotate secret-key")+"\n"+inlineCode("/rotate sharing-key"), true),
			field("ℹ️ 帮助", inlineCode("/help"), true),
		}),
		hr(),
		collapsiblePanel("🈶 中文别名", strings.Join([]string{
			"开启公开访问",
			"关闭公开访问",
			"授权音乐统计",
			"取消授权音乐统计",
			"查看我的信息",
			"轮转数据上报密钥",
			"轮转个人主页/飞书签名链接",
			"推荐配置",
			"帮助",
		}, "\n\n")),
		markdownWithSize("<font color='grey'>📡 Share My Status Plus</font>", "notation"),
	})
}

func buildPublicStatusCard(enabled bool, app *config.AppConfig, sharingKey string) map[string]any {
	if enabled {
		return buildBaseCard("green", "🌐 公开访问已开启", "个人主页现在可以公开访问", "公开访问已开启", []map[string]any{
			markdown("**公开访问已开启。**\n\n其他人可以通过个人主页实时查看你公开的状态信息。"),
			hr(),
			div([]map[string]any{
				field("🏠 个人主页", inlineOptionalURL(buildUserProfileURL(app.UserProfileURLTemplate, sharingKey), "USER_PROFILE_URL_TEMPLATE"), false),
				field("✍️ 飞书签名链接", inlineOptionalURL(buildSignatureURL(app.FeishuSignatureURLTemplate, sharingKey), "FEISHU_SIGNATURE_URL_TEMPLATE"), false),
				field("🌐 公开访问", statusText(true, "开启", "关闭"), true),
			}),
			markdownWithSize("<font color='grey'>📡 Share My Status Plus</font>", "notation"),
		})
	}

	return buildBaseCard("grey", "🌐 公开访问已关闭", "Web 个人主页已停止公开访问", "公开访问已关闭", []map[string]any{
		markdown("**公开访问已关闭。**\n\n个人主页将不再对外公开展示状态；飞书签名链接仍可用于签名预览能力。"),
		hr(),
		div([]map[string]any{
			field("🌐 公开访问", statusText(false, "开启", "关闭"), true),
			field("✍️ 飞书签名链接", inlineOptionalURL(buildSignatureURL(app.FeishuSignatureURLTemplate, sharingKey), "FEISHU_SIGNATURE_URL_TEMPLATE"), false),
		}),
		markdownWithSize("<font color='grey'>📡 Share My Status Plus</font>", "notation"),
	})
}

func buildStatStatusCard(enabled bool, app *config.AppConfig, sharingKey string) map[string]any {
	if enabled {
		return buildBaseCard("green", "📈 音乐统计已授权", "云端开始存储音乐上报信息", "音乐统计已授权", []map[string]any{
			markdown("**音乐统计授权已开启。**\n\n云端会开始存储音乐上报信息，统计数据每小时整点刷新。"),
			hr(),
			div([]map[string]any{
				field("📈 音乐统计", statusText(true, "已授权", "未授权"), true),
				field("⏱ 刷新节奏", "每小时整点", true),
				field("🏠 个人主页", inlineOptionalURL(buildUserProfileURL(app.UserProfileURLTemplate, sharingKey), "USER_PROFILE_URL_TEMPLATE"), false),
			}),
			markdownWithSize("<font color='grey'>📡 Share My Status Plus</font>", "notation"),
		})
	}

	return buildBaseCard("grey", "📈 音乐统计已关闭", "历史音乐统计记录已清空", "音乐统计已关闭", []map[string]any{
		markdown("**音乐统计授权已关闭。**\n\n云端已清空该账户的历史音乐统计记录，后续也不会继续写入统计数据。"),
		hr(),
		div([]map[string]any{
			field("📈 音乐统计", statusText(false, "已授权", "未授权"), true),
			field("🧹 历史记录", "已清空", true),
		}),
		markdownWithSize("<font color='grey'>📡 Share My Status Plus</font>", "notation"),
	})
}

func buildRotateSecretCard(newSecretKey string, app *config.AppConfig) map[string]any {
	return buildBaseCard("orange", "🔑 Secret Key 已轮转", "请更新客户端配置", "Secret Key 已轮转", []map[string]any{
		markdown("**新的 Secret Key 已生成。**\n\n旧 Secret Key 将不能继续上报，请尽快更新客户端配置。"),
		hr(),
		div([]map[string]any{
			field("🔑 新 Secret Key", inlineCode(newSecretKey), false),
			field("📮 上报地址", inlineCode(buildReportURL(app.Endpoint)), false),
		}),
		hr(),
		collapsiblePanel("⚙️ 配置提示", fmt.Sprintf("发送 %s 可以重新获取完整客户端配置 JSON。", inlineCode("/config"))),
		markdownWithSize("<font color='grey'>📡 Share My Status Plus</font>", "notation"),
	})
}

func buildRotateSharingCard(newSharingKey string, app *config.AppConfig) map[string]any {
	return buildBaseCard("orange", "🔗 个人主页/飞书签名链接已轮转", "请更新所有展示位置", "个人主页/飞书签名链接已轮转", []map[string]any{
		markdown("**新的 Sharing Key 已生成。**\n\n旧个人主页与旧飞书签名链接会立即失效，请更新所有正在使用的展示位置。"),
		hr(),
		div([]map[string]any{
			field("🔗 新 Sharing Key", inlineCode(newSharingKey), true),
			field("🏠 个人主页", inlineOptionalURL(buildUserProfileURL(app.UserProfileURLTemplate, newSharingKey), "USER_PROFILE_URL_TEMPLATE"), false),
			field("✍️ 飞书签名链接", inlineOptionalURL(buildSignatureURL(app.FeishuSignatureURLTemplate, newSharingKey), "FEISHU_SIGNATURE_URL_TEMPLATE"), false),
		}),
		markdownWithSize("<font color='grey'>📡 Share My Status Plus</font>", "notation"),
	})
}

func buildParamErrorCard(usages []string, example string) map[string]any {
	return buildBaseCard("yellow", "⚠️ 命令用法不正确", "请按下面格式重新发送", "命令用法不正确", []map[string]any{
		markdown("**这条命令缺少必要参数。**"),
		hr(),
		div([]map[string]any{
			field("✅ 正确用法", inlineLines(usages), false),
			field("💡 示例", inlineCode(example), true),
		}),
		markdownWithSize("<font color='grey'>📡 Share My Status Plus</font>", "notation"),
	})
}

func buildExecErrorCard(err error) map[string]any {
	return buildBaseCard("red", "❌ 执行命令失败", "后端返回错误", "执行命令失败", []map[string]any{
		markdown("**命令执行失败。**\n\n完整错误如下，方便排查时保留原始信息。"),
		hr(),
		div([]map[string]any{
			field("🧾 错误详情", inlineCode(err.Error()), false),
		}),
		hr(),
		collapsiblePanel("🛠 建议", fmt.Sprintf("稍后重试；如果持续失败，可以发送 %s 查看可用命令。", inlineCode("/help"))),
		markdownWithSize("<font color='grey'>📡 Share My Status Plus</font>", "notation"),
	})
}

func buildUserErrorCard(title string, err error) map[string]any {
	fields := []map[string]any{
		field("📌 影响", "无法继续执行当前命令", true),
		field("🛠 建议", "稍后重试或联系管理员", true),
	}
	if err != nil {
		fields = append(fields, field("🧾 错误详情", inlineCode(err.Error()), false))
	}

	return buildBaseCard("red", "❌ "+title, "暂时无法创建或读取账户", title, []map[string]any{
		markdown("**暂时无法初始化你的账户。**\n\n机器人未能创建或读取账户信息，请稍后重试。"),
		hr(),
		div(fields),
		markdownWithSize("<font color='grey'>📡 Share My Status Plus</font>", "notation"),
	})
}

func buildUnknownCommandCard() map[string]any {
	return buildBaseCard("yellow", "❓ 未知命令", "发送 /help 查看可用命令", "未知命令", []map[string]any{
		markdown("**没有识别到这条命令。**"),
		hr(),
		div([]map[string]any{
			field("ℹ️ 查看帮助", inlineCode("/help"), true),
			field("📊 查看账户", inlineCode("/info"), true),
		}),
		markdownWithSize("<font color='grey'>📡 Share My Status Plus</font>", "notation"),
	})
}

func buildBaseCard(template string, title string, subtitle string, summary string, elements []map[string]any) map[string]any {
	return map[string]any{
		"schema": "2.0",
		"config": map[string]any{
			"update_multi":   true,
			"enable_forward": true,
			"width_mode":     "fill",
			"summary": map[string]any{
				"content": summary,
			},
		},
		"header": map[string]any{
			"template": template,
			"title": map[string]any{
				"tag":     "plain_text",
				"content": title,
			},
			"subtitle": map[string]any{
				"tag":     "plain_text",
				"content": subtitle,
			},
		},
		"body": map[string]any{
			"direction":        "vertical",
			"vertical_spacing": "medium",
			"elements":         elements,
		},
	}
}

func markdown(content string) map[string]any {
	return map[string]any{
		"tag":     "markdown",
		"content": content,
	}
}

func markdownWithSize(content string, textSize string) map[string]any {
	element := markdown(content)
	element["text_size"] = textSize
	return element
}

func hr() map[string]any {
	return map[string]any{"tag": "hr"}
}

func div(fields []map[string]any) map[string]any {
	return map[string]any{
		"tag":    "div",
		"fields": fields,
	}
}

func field(label string, value string, isShort bool) map[string]any {
	return map[string]any{
		"is_short": isShort,
		"text": map[string]any{
			"tag":     "lark_md",
			"content": fmt.Sprintf("**%s**\n%s", label, value),
		},
	}
}

func collapsiblePanel(title string, content string) map[string]any {
	return map[string]any{
		"tag":      "collapsible_panel",
		"expanded": false,
		"header": map[string]any{
			"title": map[string]any{
				"tag":     "markdown",
				"content": title,
			},
			"background_color":    "grey",
			"padding":             "4px 8px 4px 8px",
			"icon":                map[string]any{"tag": "standard_icon", "token": "down-small-ccm_outlined", "size": "16px 16px"},
			"icon_position":       "right",
			"icon_expanded_angle": -180,
		},
		"elements": []map[string]any{
			markdown(content),
		},
	}
}

func buildReportURL(endpoint string) string {
	return strings.TrimRight(endpoint, "/") + "/api/v1/state/report"
}

func buildSignatureURL(template string, sharingKey string) string {
	if strings.TrimSpace(template) == "" {
		return ""
	}
	return strings.ReplaceAll(template, "{SharingKey}", sharingKey)
}

func buildSignatureDIYURL(template string, sharingKey string) string {
	if strings.TrimSpace(template) == "" {
		return ""
	}
	return strings.ReplaceAll(template, "{SharingKey}", sharingKey)
}

func buildUserProfileURL(template string, sharingKey string) string {
	if strings.TrimSpace(template) == "" {
		return ""
	}
	return strings.ReplaceAll(template, "{SharingKey}", sharingKey)
}

func inlineOptionalURL(value string, envName string) string {
	if strings.TrimSpace(value) == "" {
		return inlineCode("未配置 " + envName)
	}
	return inlineCode(value)
}

func rawOptionalURL(value string, envName string) string {
	if strings.TrimSpace(value) == "" {
		return inlineCode("未配置 " + envName)
	}
	return value
}

func inlineCode(value string) string {
	return "`" + strings.ReplaceAll(value, "`", "'") + "`"
}

func inlineLines(values []string) string {
	lines := make([]string, 0, len(values))
	for _, value := range values {
		lines = append(lines, inlineCode(value))
	}
	return strings.Join(lines, "\n")
}

func statusText(enabled bool, enabledText string, disabledText string) string {
	if enabled {
		return fmt.Sprintf("<font color='green'>%s</font>", enabledText)
	}
	return fmt.Sprintf("<font color='grey'>%s</font>", disabledText)
}
