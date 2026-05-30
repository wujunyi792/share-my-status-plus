package render

import (
	"strings"
	"testing"
	"time"

	common "share-my-status/api/model/share_my_status/common"
)

func TestRenderTemplateDefaultAndNilState(t *testing.T) {
	got := RenderTemplate(DefaultTemplate, nil)
	want := "正在听-未在播放"
	if got != want {
		t.Fatalf("RenderTemplate() = %q, want %q", got, want)
	}
}

func TestRenderTemplateStateVariables(t *testing.T) {
	state := &common.StatusSnapshot{
		Music: &common.Music{
			Artist: strPtr("Artist"),
			Title:  strPtr("Title"),
			Album:  strPtr("Album"),
		},
		System: &common.System{
			BatteryPct: floatPtr(0.82),
			CpuPct:     floatPtr(0.37),
			MemoryPct:  floatPtr(0.62),
		},
		Activity: &common.Activity{
			Label: "在研发",
		},
	}

	template := "{artist}-{title}/{album}/{activityLabel}/{batteryPct}/{batteryPctRounded}/{cpuPct}/{cpuPctRounded}/{memoryPct}/{memoryPctRounded}"
	got := RenderTemplate(template, state)
	want := "Artist-Title/Album/在研发/0.82/82%/0.37/37%/0.62/62%"
	if got != want {
		t.Fatalf("RenderTemplate() = %q, want %q", got, want)
	}
}

func TestRenderTemplateTimeVariables(t *testing.T) {
	got := RenderTemplate("{dateYMD}|{nowLocal}|{nowISO}", nil)
	today := time.Now().Format("2006-01-02")

	if !strings.Contains(got, today) {
		t.Fatalf("RenderTemplate() = %q, want current date %q", got, today)
	}
	if strings.Contains(got, "{dateYMD}") || strings.Contains(got, "{nowLocal}") || strings.Contains(got, "{nowISO}") {
		t.Fatalf("RenderTemplate() left time placeholders unresolved: %q", got)
	}
}

func TestRenderTemplateChargingConditions(t *testing.T) {
	template := "{charging?'充电中':'未充电'}|{charging?'充电中':'未在充电'}"

	charging := &common.StatusSnapshot{
		System: &common.System{
			Charging: boolPtr(true),
		},
	}
	if got, want := RenderTemplate(template, charging), "充电中|充电中"; got != want {
		t.Fatalf("RenderTemplate(charging) = %q, want %q", got, want)
	}

	notCharging := &common.StatusSnapshot{
		System: &common.System{
			Charging: boolPtr(false),
		},
	}
	if got, want := RenderTemplate(template, notCharging), "未充电|未在充电"; got != want {
		t.Fatalf("RenderTemplate(notCharging) = %q, want %q", got, want)
	}
}

func TestRenderTemplateMissingFieldsFallback(t *testing.T) {
	got := RenderTemplate("{artist}|{title}|{album}|{batteryPct}|{batteryPctRounded}|{activityLabel}", &common.StatusSnapshot{})
	want := "|未在播放||||"
	if got != want {
		t.Fatalf("RenderTemplate() = %q, want %q", got, want)
	}
}

func strPtr(v string) *string {
	return &v
}

func floatPtr(v float64) *float64 {
	return &v
}

func boolPtr(v bool) *bool {
	return &v
}
