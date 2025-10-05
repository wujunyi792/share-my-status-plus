package share_my_status

import (
	"context"
	"encoding/base64"
	"fmt"
	"strings"

	cover "share-my-status/api/model/share_my_status/cover"
	state "share-my-status/api/model/share_my_status/state"
	stats "share-my-status/api/model/share_my_status/stats"
	websocket "share-my-status/api/model/share_my_status/websocket"
	"share-my-status/infra"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/protocol/consts"
	"github.com/sirupsen/logrus"
)

// BatchReport 批量上报状态
// @router /v1/state/report [POST]
func BatchReport(ctx context.Context, c *app.RequestContext) {
	responseHelper := NewResponseHelper()

	var req state.BatchReportRequest
	if err := c.BindAndValidate(&req); err != nil {
		responseHelper.SendErrorResponse(c, &state.BatchReportResponse{}, 400, "Invalid request: "+err.Error())
		return
	}

	// 获取用户ID
	openID, exists := c.Get("open_id")
	if !exists {
		responseHelper.SendErrorResponse(c, &state.BatchReportResponse{}, 401, "Unauthorized")
		return
	}

	// 获取依赖并创建状态服务
	resp, err := infra.GetGlobalAppDependencies().StateService.BatchReport(ctx, openID.(string), req.Events)
	if err != nil {
		logrus.Errorf("Failed to batch report: %v", err)
		responseHelper.SendErrorResponse(c, &state.BatchReportResponse{}, 500, "Internal server error")
		return
	}

	responseHelper.SendSuccessResponseWithAutoBase(c, &state.BatchReportResponse{}, resp)
}

// QueryState 查询状态
// @router /v1/state/query [GET]
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

	responseHelper.SendSuccessResponseWithAutoBase(c, &state.QueryStateResponse{}, resp)
}

// QueryStats 查询统计
// @router /v1/stats/query [POST]
func QueryStats(ctx context.Context, c *app.RequestContext) {
	responseHelper := NewResponseHelper()

	var req stats.StatsQueryRequest
	if err := c.BindAndValidate(&req); err != nil {
		responseHelper.SendErrorResponse(c, &stats.StatsQueryResponse{}, 400, "Invalid request: "+err.Error())
		return
	}

	// 获取用户ID
	openID, exists := c.Get("open_id")
	if !exists {
		responseHelper.SendErrorResponse(c, &stats.StatsQueryResponse{}, 401, "Unauthorized")
		return
	}

	// 获取依赖并创建统计服务
	resp, err := infra.GetGlobalAppDependencies().StatsService.QueryStats(ctx, openID.(string), &req)
	if err != nil {
		logrus.Errorf("Failed to query stats: %v", err)
		responseHelper.SendErrorResponse(c, &stats.StatsQueryResponse{}, 500, "Internal server error")
		return
	}

	responseHelper.SendSuccessResponseWithAutoBase(c, &stats.StatsQueryResponse{}, resp)
}

// CheckExists 检查封面是否存在
// @router /v1/cover/exists [GET]
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

	// 使用自动填充Base字段的方法
	data := map[string]interface{}{
		"Exists": &exists,
	}
	responseHelper.SendSuccessResponseWithAutoBase(c, &cover.CoverExistsResponse{}, data)
}

// stringPtr 创建字符串指针的辅助函数
func stringPtr(s string) *string {
	return &s
}

// Upload 上传封面
// @router /v1/cover [POST]
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

	// 使用自动填充Base字段的方法
	uploadData := map[string]interface{}{
		"CoverHash": &coverHash,
	}
	responseHelper.SendSuccessResponseWithAutoBase(c, &cover.CoverUploadResponse{}, uploadData)
}

// Get 获取封面
// @router /v1/cover/:hash [GET]
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
// @router /v1/ws [GET]
func Connect(ctx context.Context, c *app.RequestContext) {
	responseHelper := NewResponseHelper()

	var req websocket.WSConnectRequest
	if err := c.BindAndValidate(&req); err != nil {
		responseHelper.SendErrorResponse(c, &websocket.WSConnectResponse{}, 400, "Invalid request: "+err.Error())
		return
	}

	// 获取用户ID
	openID, exists := c.Get("open_id")
	if !exists {
		responseHelper.SendErrorResponse(c, &websocket.WSConnectResponse{}, 401, "Unauthorized")
		return
	}

	// 获取WebSocket服务实例
	wsService := infra.GetGlobalAppDependencies().WSClient
	if wsService == nil {
		responseHelper.SendErrorResponse(c, &websocket.WSConnectResponse{}, 500, "WebSocket service not available")
		return
	}

	// 建立WebSocket连接
	err := wsService.Connect(ctx, c, openID.(string))
	if err != nil {
		logrus.Errorf("Failed to establish WebSocket connection: %v", err)
		responseHelper.SendErrorResponse(c, &websocket.WSConnectResponse{}, 500, "Failed to establish WebSocket connection")
		return
	}
}
