package share_my_status

import (
	"context"
	"encoding/base64"
	"fmt"
	"share-my-status/api/model/share_my_status/redirect"
	"share-my-status/model"
	"strings"

	cover "share-my-status/api/model/share_my_status/cover"
	state "share-my-status/api/model/share_my_status/state"
	stats "share-my-status/api/model/share_my_status/stats"
	websocket "share-my-status/api/model/share_my_status/websocket"
	"share-my-status/infra"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/protocol/consts"
	"github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

// BatchReport 批量上报状态
// @router /api/v1/state/report [POST]
func BatchReport(ctx context.Context, c *app.RequestContext) {
	responseHelper := NewResponseHelper()

	var req state.BatchReportRequest
	if err := c.BindAndValidate(&req); err != nil {
		responseHelper.SendErrorResponse(c, &state.BatchReportResponse{}, 400, "Invalid request: "+err.Error())
		return
	}

	// 获取用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		responseHelper.SendErrorResponse(c, &state.BatchReportResponse{}, 401, "Unauthorized")
		return
	}

	// 获取依赖并创建状态服务
	resp, err := infra.GetGlobalAppDependencies().StateService.BatchReport(ctx, userID.(uint64), req.Events)
	if err != nil {
		logrus.Errorf("Failed to batch report: %v", err)
		responseHelper.SendErrorResponse(c, &state.BatchReportResponse{}, 500, "Internal server error")
		return
	}

	responseHelper.SendSuccessResponse(c, resp)
}

// QueryState 查询状态
// @router /api/v1/state/query [GET]
func QueryState(ctx context.Context, c *app.RequestContext) {
	responseHelper := NewResponseHelper()

	var req state.QueryStateRequest
	if err := c.BindAndValidate(&req); err != nil {
		responseHelper.SendErrorResponse(c, &state.QueryStateResponse{}, 400, "Invalid request: "+err.Error())
		return
	}

	// 获取依赖并创建状态服务
	resp, err := infra.GetGlobalAppDependencies().StateService.QueryState(ctx, req.SharingKey)
	if err != nil {
		logrus.Errorf("Failed to query state: %v", err)
		responseHelper.SendErrorResponse(c, &state.QueryStateResponse{}, 500, "Internal server error")
		return
	}

	responseHelper.SendSuccessResponse(c, resp)
}

// QueryStats 查询统计
// @router /api/v1/stats/query [POST]
func QueryStats(ctx context.Context, c *app.RequestContext) {
	responseHelper := NewResponseHelper()

	var req stats.StatsQueryRequest
	if err := c.BindAndValidate(&req); err != nil {
		responseHelper.SendErrorResponse(c, &stats.StatsQueryResponse{}, 400, "Invalid request: "+err.Error())
		return
	}

	// 获取用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		responseHelper.SendErrorResponse(c, &stats.StatsQueryResponse{}, 401, "Unauthorized")
		return
	}

	// 获取依赖并创建统计服务
	resp, err := infra.GetGlobalAppDependencies().StatsService.QueryStats(ctx, userID.(uint64), &req)
	if err != nil {
		logrus.Errorf("Failed to query stats: %v", err)
		responseHelper.SendErrorResponse(c, &stats.StatsQueryResponse{}, 500, "Internal server error")
		return
	}

	responseHelper.SendSuccessResponse(c, resp)
}

// CheckExists 检查封面是否存在
// @router /api/v1/cover/exists [GET]
func CheckExists(ctx context.Context, c *app.RequestContext) {
	responseHelper := NewResponseHelper()

	var req cover.CoverExistsRequest
	if err := c.BindAndValidate(&req); err != nil {
		responseHelper.SendErrorResponse(c, &cover.CoverExistsResponse{}, 400, "Invalid request: "+err.Error())
		return
	}

	// 调用封面服务
	exists, err := infra.GetGlobalAppDependencies().CoverService.CheckCoverExists(ctx, req.Md5)
	if err != nil {
		logrus.Errorf("Failed to check cover existence: %v", err)
		responseHelper.SendErrorResponse(c, &cover.CoverExistsResponse{}, 500, "Internal server error")
		return
	}

	responseHelper.SendSuccessResponse(c, &cover.CoverExistsResponse{
		Exists:    &exists,
		CoverHash: &req.Md5,
	})
}

// Upload 上传封面
// @router /api/v1/cover [POST]
func Upload(ctx context.Context, c *app.RequestContext) {
	responseHelper := NewResponseHelper()

	var req cover.CoverUploadRequest
	if err := c.BindAndValidate(&req); err != nil {
		logrus.Errorf("Failed to bind request: %v", err)
		responseHelper.SendErrorResponse(c, &cover.CoverUploadResponse{}, 400, "Invalid request")
		return
	}

	// 调用封面服务上传，直接使用B64数据
	coverService := infra.GetGlobalAppDependencies().CoverService

	// 解析data URL格式的base64数据
	var data []byte
	var contentType string
	var err error

	b64Data := req.B64

	// 检查是否是data URL格式 (data:image/png;base64,xxx)
	if strings.HasPrefix(b64Data, "data:") {
		// 解析data URL
		parts := strings.SplitN(b64Data, ",", 2)
		if len(parts) != 2 {
			logrus.Errorf("Invalid data URL format")
			responseHelper.SendErrorResponse(c, &cover.CoverUploadResponse{}, 400, "Invalid data URL format")
			return
		}

		// 提取content type
		header := parts[0] // data:image/png;base64
		if strings.Contains(header, ";") {
			contentTypePart := strings.Split(header, ";")[0]           // data:image/png
			contentType = strings.TrimPrefix(contentTypePart, "data:") // image/png
		} else {
			contentType = "application/octet-stream" // 默认类型
		}

		// 解码base64数据
		data, err = base64.StdEncoding.DecodeString(parts[1])
		if err != nil {
			logrus.Errorf("Failed to decode base64 data: %v", err)
			responseHelper.SendErrorResponse(c, &cover.CoverUploadResponse{}, 400, "Invalid base64 data")
			return
		}
	} else {
		// 直接是base64数据，没有data URL前缀
		data, err = base64.StdEncoding.DecodeString(b64Data)
		if err != nil {
			logrus.Errorf("Failed to decode base64 data: %v", err)
			responseHelper.SendErrorResponse(c, &cover.CoverUploadResponse{}, 400, "Invalid base64 data")
			return
		}

		// 检测内容类型（简单检测）
		contentType = "image/jpeg" // 默认类型
		if len(data) >= 4 {
			if data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 {
				contentType = "image/png"
			} else if data[0] == 0xFF && data[1] == 0xD8 {
				contentType = "image/jpeg"
			} else if data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46 {
				contentType = "image/gif"
			}
		}
	}

	coverHash, err := coverService.UploadCover(ctx, data, contentType)
	if err != nil {
		logrus.Errorf("Failed to upload cover: %v", err)
		responseHelper.SendErrorResponse(c, &cover.CoverUploadResponse{}, 500, "Failed to upload cover")
		return
	}

	responseHelper.SendSuccessResponse(c, &cover.CoverUploadResponse{
		CoverHash: &coverHash,
	})
}

// Get 获取封面
// @router /api/v1/cover/:hash [GET]
func Get(ctx context.Context, c *app.RequestContext) {
	responseHelper := NewResponseHelper()

	var req cover.CoverGetRequest
	if err := c.BindAndValidate(&req); err != nil {
		responseHelper.SendErrorResponse(c, &cover.CoverGetResponse{}, 400, "Invalid request: "+err.Error())
		return
	}

	// 调用封面服务
	coverService := infra.GetGlobalAppDependencies().CoverService
	coverAsset, err := coverService.GetCover(ctx, req.Hash)
	if err != nil {
		logrus.Errorf("Failed to get cover: %v", err)
		responseHelper.SendErrorResponse(c, &cover.CoverGetResponse{}, 404, "Cover not found")
		return
	}

	// 获取二进制数据
	binaryData, err := coverService.GetCoverBinaryData(ctx, req.Hash)
	if err != nil {
		logrus.Errorf("Failed to get cover binary data: %v", err)
		responseHelper.SendErrorResponse(c, &cover.CoverGetResponse{}, 500, "Internal server error")
		return
	}

	// 获取资产元数据
	assetData := coverAsset.Asset.Data()

	// 设置响应头
	c.Header("Content-Type", assetData.ContentType)
	c.Header("Content-Length", fmt.Sprintf("%d", len(binaryData)))
	c.Header("Cache-Control", "public, max-age=86400") // 缓存1天

	// 返回二进制数据
	c.Data(consts.StatusOK, assetData.ContentType, binaryData)
}

// Connect WebSocket连接
// @router /api/v1/ws [GET]
func Connect(ctx context.Context, c *app.RequestContext) {
	// 获取WebSocket服务实例
	wsService := infra.GetGlobalAppDependencies().WSClient
	if wsService == nil {
		// 服务不可用，只能回退到HTTP响应
		logrus.Error("WebSocket service not available")
		responseHelper := NewResponseHelper()
		responseHelper.SendErrorResponse(c, &websocket.WSConnectResponse{}, 503, "WebSocket service not available")
		return
	}

	// 1. 验证请求参数
	var req websocket.WSConnectRequest
	if err := c.BindAndValidate(&req); err != nil {
		// 参数验证失败，通过WebSocket发送错误
		wsService.ConnectAndSendError(ctx, c,
			"INVALID_REQUEST",
			"Invalid request: "+err.Error(),
			false) // 不可重试
		return
	}

	// 2. 验证 sharingKey
	sharingKey := req.SharingKey
	if sharingKey == "" {
		wsService.ConnectAndSendError(ctx, c,
			"INVALID_REQUEST",
			"Missing sharingKey parameter",
			false) // 不可重试
		return
	}

	// 3. 查询用户
	db := infra.GetGlobalAppDependencies().DB
	var user model.User
	err := db.Where("sharing_key = ?", sharingKey).First(&user).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			wsService.ConnectAndSendError(ctx, c,
				"UNAUTHORIZED",
				"Sharing key not found",
				false) // 不可重试
		} else {
			logrus.Errorf("Failed to query user by sharing key: %v", err)
			wsService.ConnectAndSendError(ctx, c,
				"SERVER_ERROR",
				"Internal server error",
				true) // 可重试
		}
		return
	}

	// 4. 检查用户状态
	if user.Status != 1 {
		wsService.ConnectAndSendError(ctx, c,
			"UNAUTHORIZED",
			"User account is disabled",
			false) // 不可重试
		return
	}

	// 5. 检查用户设置中的公开授权
	var settings model.UserSettings
	err = db.Where("user_id = ?", user.ID).First(&settings).Error
	if err != nil && err != gorm.ErrRecordNotFound {
		logrus.Errorf("Failed to query user settings: %v", err)
		wsService.ConnectAndSendError(ctx, c,
			"SERVER_ERROR",
			"Internal server error",
			true) // 可重试
		return
	}

	// 6. 检查公开授权状态
	if !settings.Settings.Data().PublicEnabled {
		wsService.ConnectAndSendError(ctx, c,
			"UNAUTHORIZED",
			"Public access is disabled",
			false) // 不可重试
		return
	}

	// 7. 建立WebSocket连接
	err = wsService.Connect(ctx, c, user.ID)
	if err != nil {
		logrus.Errorf("Failed to establish WebSocket connection: %v", err)
		// 连接建立失败，尝试通过WebSocket发送错误
		wsService.ConnectAndSendError(ctx, c,
			"CONNECTION_FAILED",
			"Failed to establish WebSocket connection: "+err.Error(),
			true) // 可重试
		return
	}
}

// Redirect .
// @router /s/{sharingKey} [GET]
func Redirect(ctx context.Context, c *app.RequestContext) {
	var req redirect.RedirectRequest
	if err := c.BindAndValidate(&req); err != nil {
		NewResponseHelper().SendErrorResponse(c, &redirect.RedirectResponse{}, 400, "Invalid request: "+err.Error())
		return
	}

	// 获取查询参数 r
	redirectURL := req.GetR()

	// 如果没有提供 r 参数，使用默认配置
	if redirectURL == "" {
		// 从配置中获取默认跳转目标，并替换占位符
		defaultTarget := infra.GetGlobalAppDependencies().Config.Redirect.DefaultTarget
		redirectURL = strings.Replace(defaultTarget, "{SharingKey}", req.GetSharingKey(), -1)
	}

	// 进行 302 重定向
	c.Redirect(consts.StatusFound, []byte(redirectURL))
}
