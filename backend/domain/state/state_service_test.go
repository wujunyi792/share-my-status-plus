package state

import (
	"testing"

	common "share-my-status/api/model/share_my_status/common"
)

func TestStateService_mergeSnapshots(t *testing.T) {
	service := &StateService{}

	tests := []struct {
		name     string
		existing *common.StatusSnapshot
		new      *common.StatusSnapshot
		expected *common.StatusSnapshot
	}{
		{
			name: "merge system info - partial update",
			existing: &common.StatusSnapshot{
				LastUpdateTs: 1000,
				System: &common.System{
					BatteryPct: func() *float64 { v := 0.8; return &v }(),
					Charging:   func() *bool { v := true; return &v }(),
					CpuPct:     func() *float64 { v := 0.5; return &v }(),
					MemoryPct:  func() *float64 { v := 0.6; return &v }(),
				},
			},
			new: &common.StatusSnapshot{
				LastUpdateTs: 2000,
				System: &common.System{
					BatteryPct: func() *float64 { v := 0.7; return &v }(), // 更新电池
					// 其他字段为空，应该保留原值
				},
			},
			expected: &common.StatusSnapshot{
				LastUpdateTs: 2000,
				System: &common.System{
					BatteryPct: func() *float64 { v := 0.7; return &v }(), // 新值
					Charging:   func() *bool { v := true; return &v }(),    // 保留原值
					CpuPct:     func() *float64 { v := 0.5; return &v }(),  // 保留原值
					MemoryPct:  func() *float64 { v := 0.6; return &v }(),  // 保留原值
				},
			},
		},
		{
			name: "merge music info - partial update",
			existing: &common.StatusSnapshot{
				LastUpdateTs: 1000,
				Music: &common.Music{
					Title:     func() *string { v := "Old Song"; return &v }(),
					Artist:    func() *string { v := "Old Artist"; return &v }(),
					Album:     func() *string { v := "Old Album"; return &v }(),
					CoverHash: func() *string { v := "old_hash"; return &v }(),
				},
			},
			new: &common.StatusSnapshot{
				LastUpdateTs: 2000,
				Music: &common.Music{
					Title:  func() *string { v := "New Song"; return &v }(), // 更新歌曲名
					Artist: func() *string { v := "New Artist"; return &v }(), // 更新歌手
					// Album 和 CoverHash 为空，应该保留原值
				},
			},
			expected: &common.StatusSnapshot{
				LastUpdateTs: 2000,
				Music: &common.Music{
					Title:     func() *string { v := "New Song"; return &v }(),    // 新值
					Artist:    func() *string { v := "New Artist"; return &v }(),  // 新值
					Album:     func() *string { v := "Old Album"; return &v }(),   // 保留原值
					CoverHash: func() *string { v := "old_hash"; return &v }(),    // 保留原值
				},
			},
		},
		{
			name: "merge activity info",
			existing: &common.StatusSnapshot{
				LastUpdateTs: 1000,
				Activity: &common.Activity{
					Label: "在工作",
				},
			},
			new: &common.StatusSnapshot{
				LastUpdateTs: 2000,
				Activity: &common.Activity{
					Label: "在写代码",
				},
			},
			expected: &common.StatusSnapshot{
				LastUpdateTs: 2000,
				Activity: &common.Activity{
					Label: "在写代码", // 新值
				},
			},
		},
		{
			name: "new snapshot with nil existing",
			existing: &common.StatusSnapshot{
				LastUpdateTs: 1000,
			},
			new: &common.StatusSnapshot{
				LastUpdateTs: 2000,
				System: &common.System{
					BatteryPct: func() *float64 { v := 0.9; return &v }(),
				},
				Music: &common.Music{
					Title: func() *string { v := "New Song"; return &v }(),
				},
				Activity: &common.Activity{
					Label: "在学习",
				},
			},
			expected: &common.StatusSnapshot{
				LastUpdateTs: 2000,
				System: &common.System{
					BatteryPct: func() *float64 { v := 0.9; return &v }(),
				},
				Music: &common.Music{
					Title: func() *string { v := "New Song"; return &v }(),
				},
				Activity: &common.Activity{
					Label: "在学习",
				},
			},
		},
		{
			name: "empty string should not override existing values",
			existing: &common.StatusSnapshot{
				LastUpdateTs: 1000,
				Music: &common.Music{
					Title:  func() *string { v := "Existing Song"; return &v }(),
					Artist: func() *string { v := "Existing Artist"; return &v }(),
				},
			},
			new: &common.StatusSnapshot{
				LastUpdateTs: 2000,
				Music: &common.Music{
					Title:  func() *string { v := ""; return &v }(), // 空字符串不应该覆盖
					Artist: func() *string { v := "New Artist"; return &v }(),
				},
			},
			expected: &common.StatusSnapshot{
				LastUpdateTs: 2000,
				Music: &common.Music{
					Title:  func() *string { v := "Existing Song"; return &v }(), // 保留原值
					Artist: func() *string { v := "New Artist"; return &v }(),    // 新值
				},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := service.mergeSnapshots(tt.existing, tt.new)

			// 检查时间戳
			if result.LastUpdateTs != tt.expected.LastUpdateTs {
				t.Errorf("LastUpdateTs = %v, want %v", result.LastUpdateTs, tt.expected.LastUpdateTs)
			}

			// 检查系统信息
			if tt.expected.System != nil {
				if result.System == nil {
					t.Errorf("System is nil, want non-nil")
				} else {
					if tt.expected.System.BatteryPct != nil {
						if result.System.BatteryPct == nil || *result.System.BatteryPct != *tt.expected.System.BatteryPct {
							t.Errorf("BatteryPct = %v, want %v", result.System.BatteryPct, tt.expected.System.BatteryPct)
						}
					}
					if tt.expected.System.Charging != nil {
						if result.System.Charging == nil || *result.System.Charging != *tt.expected.System.Charging {
							t.Errorf("Charging = %v, want %v", result.System.Charging, tt.expected.System.Charging)
						}
					}
					if tt.expected.System.CpuPct != nil {
						if result.System.CpuPct == nil || *result.System.CpuPct != *tt.expected.System.CpuPct {
							t.Errorf("CpuPct = %v, want %v", result.System.CpuPct, tt.expected.System.CpuPct)
						}
					}
					if tt.expected.System.MemoryPct != nil {
						if result.System.MemoryPct == nil || *result.System.MemoryPct != *tt.expected.System.MemoryPct {
							t.Errorf("MemoryPct = %v, want %v", result.System.MemoryPct, tt.expected.System.MemoryPct)
						}
					}
				}
			}

			// 检查音乐信息
			if tt.expected.Music != nil {
				if result.Music == nil {
					t.Errorf("Music is nil, want non-nil")
				} else {
					if tt.expected.Music.Title != nil {
						if result.Music.Title == nil || *result.Music.Title != *tt.expected.Music.Title {
							t.Errorf("Music.Title = %v, want %v", result.Music.Title, tt.expected.Music.Title)
						}
					}
					if tt.expected.Music.Artist != nil {
						if result.Music.Artist == nil || *result.Music.Artist != *tt.expected.Music.Artist {
							t.Errorf("Music.Artist = %v, want %v", result.Music.Artist, tt.expected.Music.Artist)
						}
					}
					if tt.expected.Music.Album != nil {
						if result.Music.Album == nil || *result.Music.Album != *tt.expected.Music.Album {
							t.Errorf("Music.Album = %v, want %v", result.Music.Album, tt.expected.Music.Album)
						}
					}
					if tt.expected.Music.CoverHash != nil {
						if result.Music.CoverHash == nil || *result.Music.CoverHash != *tt.expected.Music.CoverHash {
							t.Errorf("Music.CoverHash = %v, want %v", result.Music.CoverHash, tt.expected.Music.CoverHash)
						}
					}
				}
			}

			// 检查活动信息
			if tt.expected.Activity != nil {
				if result.Activity == nil {
					t.Errorf("Activity is nil, want non-nil")
				} else {
					if result.Activity.Label != tt.expected.Activity.Label {
						t.Errorf("Activity.Label = %v, want %v", result.Activity.Label, tt.expected.Activity.Label)
					}
				}
			}
		})
	}
}