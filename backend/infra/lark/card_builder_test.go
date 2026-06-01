package lark

import (
	"encoding/json"
	"strings"
	"testing"

	"share-my-status/infra/config"
	"share-my-status/model"
)

func TestBuildAccountInfoCardUsesConfirmedLayout(t *testing.T) {
	app := &config.AppConfig{
		Endpoint:                   "https://status-sharing.mjclouds.com/",
		UserProfileURLTemplate:     "https://status-sharing.mjclouds.com/status/{SharingKey}",
		FeishuSignatureURLTemplate: "https://status-sharing.mjclouds.com/s/{SharingKey}",
		FeishuSignatureDIYURL:      "https://magic.solutionsuite.cn/diy?sharingKey={SharingKey}",
		UserDocURL:                 "https://example.com/share-my-status-doc",
	}
	user := &model.User{
		SecretKey:  []byte("preview-secret-key"),
		SharingKey: "preview-sharing-key",
	}

	card := buildAccountInfoCard(user, app, true, true)
	requireCardSkeleton(t, card)

	contents := accountFieldContents(t, card)
	want := []string{
		"**🏠 个人主页**\n`https://status-sharing.mjclouds.com/status/preview-sharing-key`",
		"**✍️ 飞书签名链接**\n`https://status-sharing.mjclouds.com/s/preview-sharing-key`",
		"**🛠 个性签名 DIY**\n`https://magic.solutionsuite.cn/diy?sharingKey=preview-sharing-key`",
		"**📮 上报地址**\n`https://status-sharing.mjclouds.com/api/v1/state/report`",
		"**🔑 Secret Key**\n`preview-secret-key`",
		"**🌐 公开访问**\n<font color='green'>开启</font>",
		"**📈 音乐统计**\n<font color='green'>已授权</font>",
		"**📘 用户文档**\nhttps://example.com/share-my-status-doc",
	}
	if len(contents) != len(want) {
		t.Fatalf("field count = %d, want %d: %#v", len(contents), len(want), contents)
	}
	for i := range want {
		if contents[i] != want[i] {
			t.Fatalf("field %d = %q, want %q", i, contents[i], want[i])
		}
	}

	raw := mustJSON(t, card)
	if strings.Contains(raw, "Sharing Key") {
		t.Fatalf("account info card should not display Sharing Key: %s", raw)
	}
	if strings.Contains(raw, "分享链接") {
		t.Fatalf("account info card should use 个人主页 wording, not 分享链接: %s", raw)
	}
}

func TestBuildAccountInfoCardMissingOptionalURLs(t *testing.T) {
	app := &config.AppConfig{
		Endpoint: "https://status-sharing.mjclouds.com",
	}
	user := &model.User{
		SecretKey:  []byte("preview-secret-key"),
		SharingKey: "preview-sharing-key",
	}

	card := buildAccountInfoCard(user, app, false, false)
	requireCardSkeleton(t, card)

	contents := accountFieldContents(t, card)
	assertContains(t, contents[0], "`未配置 USER_PROFILE_URL_TEMPLATE`")
	assertContains(t, contents[1], "`未配置 FEISHU_SIGNATURE_URL_TEMPLATE`")
	assertContains(t, contents[2], "`未配置 FEISHU_SIGNATURE_DIY_URL`")
	assertContains(t, contents[5], "<font color='grey'>关闭</font>")
	assertContains(t, contents[6], "<font color='grey'>未授权</font>")
	assertContains(t, contents[7], "`未配置 USER_DOC_URL`")
}

func TestBuildConfigCardUsesV2InteractiveSkeleton(t *testing.T) {
	app := &config.AppConfig{
		Endpoint: "https://status-sharing.mjclouds.com",
	}
	user := &model.User{
		SecretKey:  []byte("preview-secret-key"),
		SharingKey: "preview-sharing-key",
	}

	card := buildConfigCard(`{"endpointURL":"https://status-sharing.mjclouds.com/api/v1/state/report"}`, user, app)
	requireCardSkeleton(t, card)

	raw := mustJSON(t, card)
	assertContains(t, raw, "```json")
	assertContains(t, raw, "**📮 上报地址**\\n`https://status-sharing.mjclouds.com/api/v1/state/report`")
	assertContains(t, raw, "**🔑 Secret Key**\\n`preview-secret-key`")
}

func requireCardSkeleton(t *testing.T, card map[string]any) {
	t.Helper()
	if got := card["schema"]; got != "2.0" {
		t.Fatalf("schema = %#v, want 2.0", got)
	}
	body, ok := card["body"].(map[string]any)
	if !ok {
		t.Fatalf("body missing or wrong type: %#v", card["body"])
	}
	elements, ok := body["elements"].([]map[string]any)
	if !ok || len(elements) == 0 {
		t.Fatalf("body.elements missing or empty: %#v", body["elements"])
	}
}

func accountFieldContents(t *testing.T, card map[string]any) []string {
	t.Helper()
	body := card["body"].(map[string]any)
	elements := body["elements"].([]map[string]any)
	fields := elements[0]["fields"].([]map[string]any)
	contents := make([]string, 0, len(fields))
	for _, field := range fields {
		text := field["text"].(map[string]any)
		contents = append(contents, text["content"].(string))
	}
	return contents
}

func mustJSON(t *testing.T, value any) string {
	t.Helper()
	data, err := json.Marshal(value)
	if err != nil {
		t.Fatalf("json marshal failed: %v", err)
	}
	return string(data)
}

func assertContains(t *testing.T, haystack any, needle string) {
	t.Helper()
	text := ""
	switch v := haystack.(type) {
	case string:
		text = v
	case []string:
		text = strings.Join(v, "\n")
	default:
		t.Fatalf("unsupported haystack type %T", haystack)
	}
	if !strings.Contains(text, needle) {
		t.Fatalf("expected %q to contain %q", text, needle)
	}
}
