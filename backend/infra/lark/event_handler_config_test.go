package lark

import (
	"encoding/json"
	"slices"
	"strings"
	"testing"

	"share-my-status/infra/config"
	"share-my-status/model"
)

// 统一推荐配置:每个活动分组必须同时带 bundleIds(macOS)与 processNames(Windows),
// 两端默认分组名必须能对齐(否则会有一侧为空)。这是防止两端 DefaultSettings 漂移的护栏。
func TestUnifiedActivityGroupsCarryBothPlatforms(t *testing.T) {
	groups := unifiedActivityGroups()
	if len(groups) == 0 {
		t.Fatal("unifiedActivityGroups() 为空")
	}
	for _, g := range groups {
		name, _ := g["name"].(string)

		bundleIds, ok := g["bundleIds"].([]string)
		if !ok || len(bundleIds) == 0 {
			t.Errorf("分组 %q 缺少 bundleIds(macOS)", name)
		}
		procs, ok := g["processNames"].([]string)
		if !ok || len(procs) == 0 {
			t.Errorf("分组 %q 缺少 processNames(Windows)——可能是两端分组名未对齐", name)
		}
	}
}

// 推荐配置必须携带 macOS 默认音乐白名单(bundle ID 在 macOS 上可靠,白名单有效,
// 存量 mac 用户依赖它)。Windows 会忽略该字段,所以放它不影响 Windows。此外 macOS
// 旧客户端的导入解码器把 musicAppWhitelist 当必填字段,缺失会导致导入失败——所以这
// 个字段绝不能省略。
func TestRecommendedConfigCarriesMacMusicWhitelist(t *testing.T) {
	h := &EventHandler{}
	user := &model.User{SecretKey: []byte("k")}
	cfg := &config.AppConfig{Endpoint: "https://example.com"}

	raw := h.buildRecommendedConfigJSON(user, cfg)

	var parsed struct {
		MusicAppWhitelist []string `json:"musicAppWhitelist"`
	}
	if err := json.Unmarshal([]byte(raw), &parsed); err != nil {
		t.Fatalf("推荐配置 JSON 解析失败: %v", err)
	}
	if len(parsed.MusicAppWhitelist) == 0 {
		t.Fatal("musicAppWhitelist 为空——macOS 存量用户的默认白名单丢失了")
	}
	for _, want := range []string{"com.apple.Music", "com.netease.163music", "com.tencent.QQMusicMac"} {
		if !slices.Contains(parsed.MusicAppWhitelist, want) {
			t.Errorf("musicAppWhitelist 缺少 %q", want)
		}
	}
	// 同时确认字段确实出现在 JSON 文本里(不是被序列化成 null/省略)。
	if !strings.Contains(raw, `"musicAppWhitelist"`) {
		t.Error("JSON 文本里没有 musicAppWhitelist 字段")
	}
}
