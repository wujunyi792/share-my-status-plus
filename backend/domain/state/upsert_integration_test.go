package state

// Integration test for the jsonb `||` atomic upsert used by processEvent.
// Gated by SMS_TEST_DSN so it is skipped in CI / normal `go test` (which have no Postgres).
// Run locally with:
//   SMS_TEST_DSN="host=localhost port=55432 user=postgres dbname=smstest sslmode=disable" \
//     go test ./domain/state/ -run TestUpsert -v

import (
	"context"
	"encoding/json"
	"os"
	"sync"
	"testing"

	common "share-my-status/api/model/share_my_status/common"
	"share-my-status/model"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func f64(v float64) *float64 { return &v }
func strp(v string) *string  { return &v }

func openTestDB(t *testing.T) *gorm.DB {
	dsn := os.Getenv("SMS_TEST_DSN")
	if dsn == "" {
		t.Skip("SMS_TEST_DSN not set; skipping Postgres integration test")
	}
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	if err := db.AutoMigrate(&model.CurrentState{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	if err := db.Exec("DELETE FROM current_state").Error; err != nil {
		t.Fatalf("clean: %v", err)
	}
	return db
}

// upsert replicates processEvent's exact SQL + serialization.
func upsert(t *testing.T, db *gorm.DB, userID uint64, snap *common.StatusSnapshot) *common.StatusSnapshot {
	t.Helper()
	b, err := json.Marshal(snap)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	var row struct {
		Snapshot []byte `gorm:"column:snapshot"`
	}
	err = db.WithContext(context.Background()).Raw(
		`INSERT INTO current_state (user_id, snapshot, updated_at)
		 VALUES (?, ?::jsonb, now())
		 ON CONFLICT (user_id) DO UPDATE
		   SET snapshot = current_state.snapshot || EXCLUDED.snapshot, updated_at = now()
		 RETURNING snapshot`,
		userID, string(b),
	).Scan(&row).Error
	if err != nil {
		t.Fatalf("upsert: %v", err)
	}
	var merged common.StatusSnapshot
	if len(row.Snapshot) > 0 {
		if err := json.Unmarshal(row.Snapshot, &merged); err != nil {
			t.Fatalf("unmarshal merged: %v", err)
		}
	}
	return &merged
}

// TestUpsertFirstInsert: ON CONFLICT not triggered; row created with provided modules.
func TestUpsertFirstInsert(t *testing.T) {
	db := openTestDB(t)
	got := upsert(t, db, 1, &common.StatusSnapshot{
		LastUpdateTs: 100,
		System:       &common.System{BatteryPct: f64(0.8)},
		Music:        &common.Music{Title: strp("Song A")},
	})
	if got.System == nil || got.System.BatteryPct == nil || *got.System.BatteryPct != 0.8 {
		t.Fatalf("first insert: system missing/wrong: %+v", got.System)
	}
	if got.Music == nil || got.Music.Title == nil || *got.Music.Title != "Song A" {
		t.Fatalf("first insert: music missing/wrong: %+v", got.Music)
	}
	if got.LastUpdateTs != 100 {
		t.Fatalf("first insert: ts = %d, want 100", got.LastUpdateTs)
	}
}

// TestUpsertModuleMerge: a music-only report must REPLACE music, PRESERVE system, UPDATE ts.
// This is the core equivalence with the old Go mergeSnapshots.
func TestUpsertModuleMerge(t *testing.T) {
	db := openTestDB(t)
	_ = upsert(t, db, 1, &common.StatusSnapshot{
		LastUpdateTs: 100,
		System:       &common.System{BatteryPct: f64(0.8)},
		Music:        &common.Music{Title: strp("Old Song")},
	})
	got := upsert(t, db, 1, &common.StatusSnapshot{
		LastUpdateTs: 200,
		Music:        &common.Music{Title: strp("New Song")}, // system/activity omitted (omitempty)
	})

	// system preserved (the null-overwrite guard: omitempty means it isn't in EXCLUDED)
	if got.System == nil || got.System.BatteryPct == nil || *got.System.BatteryPct != 0.8 {
		t.Fatalf("merge: system NOT preserved (null-overwrite bug?): %+v", got.System)
	}
	// music replaced
	if got.Music == nil || got.Music.Title == nil || *got.Music.Title != "New Song" {
		t.Fatalf("merge: music not replaced: %+v", got.Music)
	}
	// ts updated
	if got.LastUpdateTs != 200 {
		t.Fatalf("merge: ts = %d, want 200", got.LastUpdateTs)
	}
}

// TestUpsertConcurrency: concurrent module-specific reports must not lose each other's module
// (the old read-merge-write lost updates; the atomic upsert must not).
func TestUpsertConcurrency(t *testing.T) {
	db := openTestDB(t)
	const userID = 2
	const perModule = 20

	var wg sync.WaitGroup
	fire := func(makeSnap func(i int) *common.StatusSnapshot) {
		defer wg.Done()
		for i := 0; i < perModule; i++ {
			upsert(t, db, userID, makeSnap(i))
		}
	}
	wg.Add(3)
	go fire(func(i int) *common.StatusSnapshot {
		return &common.StatusSnapshot{LastUpdateTs: int64(1000 + i), System: &common.System{BatteryPct: f64(0.5)}}
	})
	go fire(func(i int) *common.StatusSnapshot {
		return &common.StatusSnapshot{LastUpdateTs: int64(2000 + i), Music: &common.Music{Title: strp("M")}}
	})
	go fire(func(i int) *common.StatusSnapshot {
		return &common.StatusSnapshot{LastUpdateTs: int64(3000 + i), Activity: &common.Activity{Label: "工作", Ts: 1}}
	})
	wg.Wait()

	// Read final row directly.
	var row struct {
		Snapshot []byte `gorm:"column:snapshot"`
	}
	if err := db.Raw(`SELECT snapshot FROM current_state WHERE user_id = ?`, userID).Scan(&row).Error; err != nil {
		t.Fatalf("read final: %v", err)
	}
	var final common.StatusSnapshot
	if err := json.Unmarshal(row.Snapshot, &final); err != nil {
		t.Fatalf("unmarshal final: %v", err)
	}
	if final.System == nil {
		t.Error("concurrency: lost System module")
	}
	if final.Music == nil {
		t.Error("concurrency: lost Music module")
	}
	if final.Activity == nil {
		t.Error("concurrency: lost Activity module")
	}
	t.Logf("final merged snapshot: system=%v music=%v activity=%v ts=%d",
		final.System != nil, final.Music != nil, final.Activity != nil, final.LastUpdateTs)
}
