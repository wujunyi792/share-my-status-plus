package render

import "regexp"

type TemplateConfig struct {
	DefaultTemplate string               `json:"defaultTemplate"`
	Variables       []TemplateVariable   `json:"variables"`
	Expressions     []TemplateExpression `json:"expressions"`
}

type TemplateVariable struct {
	Key         string `json:"key"`
	Placeholder string `json:"placeholder"`
	Category    string `json:"category"`
	Label       string `json:"label"`
	Type        string `json:"type"`
	Example     string `json:"example"`
}

type TemplateExpression struct {
	Kind               string   `json:"kind"`
	ConditionVariables []string `json:"conditionVariables"`
	Syntax             string   `json:"syntax"`
}

var chargingTernaryExpression = regexp.MustCompile(`\{([A-Za-z][A-Za-z0-9_]*)\?'([^']*)':'([^']*)'\}`)

var templateVariables = []TemplateVariable{
	{Key: "artist", Placeholder: "{artist}", Category: "music", Label: "歌手", Type: "string", Example: "Taylor Swift"},
	{Key: "title", Placeholder: "{title}", Category: "music", Label: "歌曲名", Type: "string", Example: "Love Story"},
	{Key: "album", Placeholder: "{album}", Category: "music", Label: "专辑名", Type: "string", Example: "1989"},
	{Key: "batteryPct", Placeholder: "{batteryPct}", Category: "system", Label: "电量小数", Type: "decimal_string", Example: "0.82"},
	{Key: "batteryPctRounded", Placeholder: "{batteryPctRounded}", Category: "system", Label: "电量百分比", Type: "percent_string", Example: "82%"},
	{Key: "cpuPct", Placeholder: "{cpuPct}", Category: "system", Label: "CPU 使用率小数", Type: "decimal_string", Example: "0.37"},
	{Key: "cpuPctRounded", Placeholder: "{cpuPctRounded}", Category: "system", Label: "CPU 使用率", Type: "percent_string", Example: "37%"},
	{Key: "memoryPct", Placeholder: "{memoryPct}", Category: "system", Label: "内存使用率小数", Type: "decimal_string", Example: "0.62"},
	{Key: "memoryPctRounded", Placeholder: "{memoryPctRounded}", Category: "system", Label: "内存使用率", Type: "percent_string", Example: "62%"},
	{Key: "activityLabel", Placeholder: "{activityLabel}", Category: "activity", Label: "当前活动", Type: "string", Example: "在研发"},
	{Key: "nowLocal", Placeholder: "{nowLocal}", Category: "time", Label: "当前本地时间", Type: "datetime_string", Example: "2026-06-01 10:20:30"},
	{Key: "dateYMD", Placeholder: "{dateYMD}", Category: "time", Label: "当前日期", Type: "date_string", Example: "2026-06-01"},
	{Key: "nowISO", Placeholder: "{nowISO}", Category: "time", Label: "当前 ISO 时间", Type: "datetime_string", Example: "2026-06-01T10:20:30+08:00"},
}

var templateExpressions = []TemplateExpression{
	{
		Kind:               "ternary",
		ConditionVariables: []string{"charging"},
		Syntax:             "{charging?'true_text':'false_text'}",
	},
}

func GetTemplateConfig() TemplateConfig {
	return TemplateConfig{
		DefaultTemplate: DefaultTemplate,
		Variables:       append([]TemplateVariable(nil), templateVariables...),
		Expressions:     append([]TemplateExpression(nil), templateExpressions...),
	}
}
