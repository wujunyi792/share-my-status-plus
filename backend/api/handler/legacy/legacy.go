package legacy

import (
	"context"
	"share-my-status/infra"
	"share-my-status/model"
	"time"

	common "share-my-status/api/model/share_my_status/common"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/sirupsen/logrus"
)

// MusicData 旧版音乐数据结构
type MusicData struct {
	Artist   string `json:"artist"`
	Title    string `json:"title"`
	Album    string `json:"album"`
	Duration string `json:"duration"`
	Artwork  string `json:"-"`
}

// ActivityRequest 旧版活动请求结构
type ActivityRequest struct {
	Key       string     `json:"key"`
	Type      string     `json:"type"`
	MusicData *MusicData `json:"musicData,omitempty"`
}

// ActivityResponse 旧版活动响应结构
type ActivityResponse struct {
	Error   int    `json:"error"`
	Message string `json:"message"`
}

// UploadStatus 处理旧版 POST /api/status/v1 接口
// @router /api/status/v1 [POST]
func UploadStatus(ctx context.Context, c *app.RequestContext) {
	var req ActivityRequest
	if err := c.BindAndValidate(&req); err != nil {
		c.JSON(400, ActivityResponse{
			Error:   1,
			Message: "Invalid request: " + err.Error(),
		})
		return
	}

	logrus.Infof("Legacy UploadStatus request: key=%s, type=%s", req.Key, req.Type)

	// 解密key获取用户ID
	var user model.User
	err := infra.GetGlobalAppDependencies().DB.Where("secret_key = ?", req.Key).First(&user).Error
	if err != nil {
		c.JSON(400, ActivityResponse{
			Error:   1,
			Message: err.Error(),
		})
		return
	}

	// 转换为新版数据结构
	events := make([]*common.ReportEvent, 0)
	currentTime := time.Now().UnixMilli()

	// 创建基础事件
	event := &common.ReportEvent{
		Version: "1",
	}

	// 根据type处理不同类型的数据
	switch req.Type {
	case "music":
		if req.MusicData != nil {
			event.Music = &common.Music{
				Title:  &req.MusicData.Title,
				Artist: &req.MusicData.Artist,
				Album:  &req.MusicData.Album,
				Ts:     currentTime,
			}
		}
	default:
		c.JSON(200, ActivityResponse{
			Error:   0,
			Message: "success",
		})
		return
	}

	events = append(events, event)

	// 调用新版BatchReport
	stateService := infra.GetGlobalAppDependencies().StateService
	resp, err := stateService.BatchReport(ctx, user.ID, events)
	if err != nil {
		logrus.Errorf("Failed to batch report: %v", err)
		c.JSON(400, ActivityResponse{
			Error:   1,
			Message: "Internal server error",
		})
		return
	}

	// 检查响应状态
	message := "success"
	if resp.Base.Message != nil {
		message = *resp.Base.Message
	}

	c.JSON(200, ActivityResponse{
		Error:   0,
		Message: message,
	})
}

// HandleLink 处理旧版 GET /link 接口
// @router /link [GET]
func HandleLink(_ context.Context, c *app.RequestContext) {
	r := c.Query("r")
	if r == "" {
		r = infra.GetGlobalAppDependencies().Config.LegacyCrypto.DefaultJumpLink
	}
	c.Redirect(307, []byte(r))
}
