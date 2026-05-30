package share_my_status

import (
	"context"
	"errors"
	"strings"

	"share-my-status/domain/render"
	"share-my-status/infra"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/common/utils"
	"github.com/cloudwego/hertz/pkg/protocol/consts"
	"github.com/sirupsen/logrus"
)

// RenderPreview 渲染飞书链接预览结构
// @router /api/v1/render [GET]
func RenderPreview(ctx context.Context, c *app.RequestContext) {
	sharingKey := strings.TrimSpace(c.Query("sharingKey"))
	if sharingKey == "" {
		c.JSON(consts.StatusBadRequest, utils.H{
			"code":    consts.StatusBadRequest,
			"message": "Missing sharingKey parameter",
		})
		return
	}

	renderService := infra.GetGlobalAppDependencies().RenderService
	preview, err := renderService.RenderBySharingKey(ctx, sharingKey, c.Query("m"))
	if err != nil {
		switch {
		case errors.Is(err, render.ErrSharingKeyNotFound):
			c.JSON(consts.StatusNotFound, utils.H{
				"code":    consts.StatusNotFound,
				"message": "Sharing key not found",
			})
		case errors.Is(err, render.ErrPublicAccessDisabled):
			c.JSON(consts.StatusForbidden, utils.H{
				"code":    consts.StatusForbidden,
				"message": "Public access is disabled",
			})
		default:
			logrus.Errorf("Failed to render preview: %v", err)
			c.JSON(consts.StatusInternalServerError, utils.H{
				"code":    consts.StatusInternalServerError,
				"message": "Internal server error",
			})
		}
		return
	}

	c.JSON(consts.StatusOK, preview)
}
