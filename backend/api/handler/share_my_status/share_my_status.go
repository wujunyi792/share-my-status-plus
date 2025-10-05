package share_my_status

import (
	"context"
	"io"

	"share-my-status/internal/service"

	common "share-my-status/api/model/share_my_status/common"
	cover "share-my-status/api/model/share_my_status/cover"
	state "share-my-status/api/model/share_my_status/state"
	stats "share-my-status/api/model/share_my_status/stats"
	websocket "share-my-status/api/model/share_my_status/websocket"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/protocol/consts"
	"github.com/sirupsen/logrus"
)

// BatchReport 批量上报状态
// @router /v1/state/report [POST]
func BatchReport(ctx context.Context, c *app.RequestContext) {
	var req state.BatchReportRequest
	if err := c.BindAndValidate(&req); err != nil {
		c.JSON(consts.StatusBadRequest, map[string]interface{}{
			"code":    400,
			"message": "Invalid request: " + err.Error(),
		})
		return
	}

	// 获取用户ID
	openID, exists := c.Get("open_id")
	if !exists {
		c.JSON(consts.StatusUnauthorized, map[string]interface{}{
			"code":    401,
			"message": "Unauthorized",
		})
		return
	}

	// 调用状态服务
	stateService := service.NewStateService()
	stateService.InitWebSocketService() // 初始化WebSocket服务
	resp, err := stateService.BatchReport(ctx, openID.(string), req.Events)
	if err != nil {
		logrus.Errorf("Failed to batch report: %v", err)
		c.JSON(consts.StatusInternalServerError, map[string]interface{}{
			"code":    500,
			"message": "Internal server error",
		})
		return
	}

	c.JSON(consts.StatusOK, resp)
}

// QueryState 查询状态
// @router /v1/state/query [GET]
func QueryState(ctx context.Context, c *app.RequestContext) {
	var req state.QueryStateRequest
	if err := c.BindAndValidate(&req); err != nil {
		c.JSON(consts.StatusBadRequest, map[string]interface{}{
			"code":    400,
			"message": "Invalid request: " + err.Error(),
		})
		return
	}

	// 调用状态服务
	stateService := service.NewStateService()
	resp, err := stateService.QueryState(ctx, req.SharingKey)
	if err != nil {
		logrus.Errorf("Failed to query state: %v", err)
		c.JSON(consts.StatusInternalServerError, map[string]interface{}{
			"code":    500,
			"message": "Internal server error",
		})
		return
	}

	c.JSON(consts.StatusOK, resp)
}

// QueryStats 查询统计
// @router /v1/stats/query [POST]
func QueryStats(ctx context.Context, c *app.RequestContext) {
	var req stats.StatsQueryRequest
	if err := c.BindAndValidate(&req); err != nil {
		c.JSON(consts.StatusBadRequest, map[string]interface{}{
			"code":    400,
			"message": "Invalid request: " + err.Error(),
		})
		return
	}

	// 获取用户ID
	openID, exists := c.Get("open_id")
	if !exists {
		c.JSON(consts.StatusUnauthorized, map[string]interface{}{
			"code":    401,
			"message": "Unauthorized",
		})
		return
	}

	// 调用统计服务
	statsService := service.NewStatsService()
	resp, err := statsService.QueryStats(ctx, openID.(string), &req)
	if err != nil {
		logrus.Errorf("Failed to query stats: %v", err)
		c.JSON(consts.StatusInternalServerError, map[string]interface{}{
			"code":    500,
			"message": "Internal server error",
		})
		return
	}

	c.JSON(consts.StatusOK, resp)
}

// CheckExists 检查封面是否存在
// @router /v1/cover/exists [GET]
func CheckExists(ctx context.Context, c *app.RequestContext) {
	var req cover.CoverExistsRequest
	if err := c.BindAndValidate(&req); err != nil {
		c.JSON(consts.StatusBadRequest, map[string]interface{}{
			"code":    400,
			"message": "Invalid request: " + err.Error(),
		})
		return
	}

	// 调用封面服务
	coverService := service.NewCoverService()
	exists, err := coverService.CheckCoverExists(ctx, req.Md5)
	if err != nil {
		logrus.Errorf("Failed to check cover existence: %v", err)
		c.JSON(consts.StatusInternalServerError, map[string]interface{}{
			"code":    500,
			"message": "Internal server error",
		})
		return
	}

	message := "success"
	resp := &cover.CoverExistsResponse{
		Base: &common.BaseResponse{
			Code:    0,
			Message: &message,
		},
		Exists: &exists,
	}

	c.JSON(consts.StatusOK, resp)
}

// Upload 上传封面
// @router /v1/cover/upload [POST]
func Upload(ctx context.Context, c *app.RequestContext) {
	var req cover.CoverUploadRequest
	if err := c.BindAndValidate(&req); err != nil {
		c.JSON(consts.StatusBadRequest, map[string]interface{}{
			"code":    400,
			"message": "Invalid request: " + err.Error(),
		})
		return
	}

	// 获取用户ID
	_, exists := c.Get("open_id")
	if !exists {
		c.JSON(consts.StatusUnauthorized, map[string]interface{}{
			"code":    401,
			"message": "Unauthorized",
		})
		return
	}

	// 获取上传的文件数据
	file, err := c.FormFile("cover")
	if err != nil {
		c.JSON(consts.StatusBadRequest, map[string]interface{}{
			"code":    400,
			"message": "Missing cover file",
		})
		return
	}

	// 打开文件
	src, err := file.Open()
	if err != nil {
		c.JSON(consts.StatusInternalServerError, map[string]interface{}{
			"code":    500,
			"message": "Failed to open uploaded file",
		})
		return
	}
	defer src.Close()

	// 读取文件数据
	data, err := io.ReadAll(src)
	if err != nil {
		c.JSON(consts.StatusInternalServerError, map[string]interface{}{
			"code":    500,
			"message": "Failed to read uploaded file",
		})
		return
	}

	// 调用封面服务上传
	coverService := service.NewCoverService()
	coverHash, err := coverService.UploadCover(ctx, data, file.Header.Get("Content-Type"))
	if err != nil {
		logrus.Errorf("Failed to upload cover: %v", err)
		c.JSON(consts.StatusInternalServerError, map[string]interface{}{
			"code":    500,
			"message": "Failed to upload cover",
		})
		return
	}

	message := "success"
	resp := &cover.CoverUploadResponse{
		Base: &common.BaseResponse{
			Code:    0,
			Message: &message,
		},
		CoverHash: &coverHash,
	}

	c.JSON(consts.StatusOK, resp)
}

// Get 获取封面
// @router /v1/cover/{hash} [GET]
func Get(ctx context.Context, c *app.RequestContext) {
	var req cover.CoverGetRequest
	if err := c.BindAndValidate(&req); err != nil {
		c.JSON(consts.StatusBadRequest, map[string]interface{}{
			"code":    400,
			"message": "Invalid request: " + err.Error(),
		})
		return
	}

	// 调用封面服务获取封面信息
	coverService := service.NewCoverService()
	coverAsset, err := coverService.GetCover(ctx, req.Hash)
	if err != nil {
		logrus.Errorf("Failed to get cover: %v", err)
		c.JSON(consts.StatusNotFound, map[string]interface{}{
			"code":    404,
			"message": "Cover not found",
		})
		return
	}

	// 设置响应头
	if contentType, ok := coverAsset.Asset["contentType"].(string); ok {
		c.Header("Content-Type", contentType)
	}

	// 返回封面数据（这里简化处理，实际应该从存储中读取二进制数据）
	c.JSON(consts.StatusOK, map[string]interface{}{
		"coverHash":   coverAsset.CoverHash,
		"contentType": coverAsset.Asset["contentType"],
		"size":        coverAsset.Asset["size"],
		"uploadTime":  coverAsset.Asset["uploadTime"],
	})
}

// Connect WebSocket连接
// @router /v1/ws [GET]
func Connect(ctx context.Context, c *app.RequestContext) {
	var req websocket.WSConnectRequest
	if err := c.BindAndValidate(&req); err != nil {
		c.JSON(consts.StatusBadRequest, map[string]interface{}{
			"code":    400,
			"message": "Invalid request: " + err.Error(),
		})
		return
	}

	// 获取用户ID
	openID, exists := c.Get("open_id")
	if !exists {
		c.JSON(consts.StatusUnauthorized, map[string]interface{}{
			"code":    401,
			"message": "Unauthorized",
		})
		return
	}

	// 获取WebSocket服务实例（这里应该从全局获取或注入）
	wsService := getWebSocketService()
	if wsService == nil {
		c.JSON(consts.StatusInternalServerError, map[string]interface{}{
			"code":    500,
			"message": "WebSocket service not available",
		})
		return
	}

	// 建立WebSocket连接
	err := wsService.Connect(ctx, c, openID.(string))
	if err != nil {
		logrus.Errorf("Failed to establish WebSocket connection: %v", err)
		c.JSON(consts.StatusInternalServerError, map[string]interface{}{
			"code":    500,
			"message": "Failed to establish WebSocket connection",
		})
		return
	}
}

// getWebSocketService 获取WebSocket服务实例
func getWebSocketService() *service.WebSocketService {
	serviceManager := service.GetServiceManager()
	return serviceManager.GetWebSocketService()
}
