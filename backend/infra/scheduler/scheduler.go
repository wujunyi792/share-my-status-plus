package scheduler

import (
	"context"
	"share-my-status/infra/config"
	"time"

	"github.com/robfig/cron/v3"
	"github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

// Scheduler 定时任务调度器
type Scheduler struct {
	cron *cron.Cron
	db   *gorm.DB
	cfg  *config.Config
}

// Task 定时任务接口
type Task interface {
	Name() string
	Execute(ctx context.Context) error
	Schedule() string // cron表达式
}

// NewScheduler 创建新的调度器实例
func NewScheduler(db *gorm.DB, cfg *config.Config) *Scheduler {
	return &Scheduler{
		cron: cron.New(cron.WithSeconds()),
		db:   db,
		cfg:  cfg,
	}
}

// Start 启动调度器
func (s *Scheduler) Start() {
	if s.cfg.Scheduler.Enabled {
		// 注册清理任务
		cleanupTask := NewCleanupTask(s.db, s.cfg)
		s.RegisterTask(cleanupTask)
	}

	s.cron.Start()
	logrus.Info("Scheduler started successfully")
}

// Stop 停止调度器
func (s *Scheduler) Stop() {
	ctx := s.cron.Stop()
	<-ctx.Done()
	logrus.Info("Scheduler stopped")
}

// RegisterTask 注册定时任务
func (s *Scheduler) RegisterTask(task Task) {
	_, err := s.cron.AddFunc(task.Schedule(), func() {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Minute)
		defer cancel()

		start := time.Now()
		err := task.Execute(ctx)
		duration := time.Since(start)

		if err != nil {
			logrus.WithFields(logrus.Fields{
				"task":     task.Name(),
				"duration": duration,
				"error":    err,
			}).Error("Task failed")
		} else {
			logrus.WithFields(logrus.Fields{
				"task":     task.Name(),
				"duration": duration,
			}).Info("Task completed successfully")
		}
	})

	if err != nil {
		logrus.WithFields(logrus.Fields{
			"task":  task.Name(),
			"error": err,
		}).Error("Failed to register task")
	} else {
		logrus.WithFields(logrus.Fields{
			"task":     task.Name(),
			"schedule": task.Schedule(),
		}).Info("Task registered")
	}
}
