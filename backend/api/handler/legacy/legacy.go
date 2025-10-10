package legacy

import (
	"context"
	"share-my-status/infra"
	"share-my-status/pkg/crypto"
	"strconv"
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
	Duration int    `json:"duration"`
	Artwork  string `json:"artwork"`
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
	config := infra.GetGlobalAppDependencies().Config
	userIDStr, err := crypto.Decode(req.Key, config.LegacyCrypto.Key, config.LegacyCrypto.IV)
	if err != nil {
		logrus.Errorf("Failed to decode key: %v", err)
		c.JSON(400, ActivityResponse{
			Error:   1,
			Message: "Invalid key",
		})
		return
	}

	userID, err := strconv.ParseUint(userIDStr, 10, 64)
	if err != nil {
		logrus.Errorf("Failed to parse user ID: %v", err)
		c.JSON(400, ActivityResponse{
			Error:   1,
			Message: "Invalid key format",
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
		// 默认处理为音乐数据
		if req.MusicData != nil {
			event.Music = &common.Music{
				Title:  &req.MusicData.Title,
				Artist: &req.MusicData.Artist,
				Album:  &req.MusicData.Album,
				Ts:     currentTime,
			}
		}
	}

	events = append(events, event)

	// 调用新版BatchReport
	stateService := infra.GetGlobalAppDependencies().StateService
	resp, err := stateService.BatchReport(ctx, userID, events)
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
