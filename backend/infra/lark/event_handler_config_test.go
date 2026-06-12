package lark

import "testing"

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
