package share_my_status

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"strings"

	"share-my-status/domain/render"
	"share-my-status/infra"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/common/utils"
	"github.com/cloudwego/hertz/pkg/protocol/consts"
	"github.com/sirupsen/logrus"
)

var (
	errRenderURLMissing = errors.New("missing render url")
	errRenderURLInvalid = errors.New("invalid render url")
)

type renderPreviewRequest struct {
	sharingKey string
	template   string
}

// RenderPreview 渲染飞书链接预览结构
// @router /api/v1/render [GET]
func RenderPreview(ctx context.Context, c *app.RequestContext) {
	req, err := parseRenderPreviewRequest(c.Query("url"), c.Query("sharingKey"), c.Query("m"))
	if err != nil {
		c.JSON(consts.StatusBadRequest, utils.H{
			"code":    consts.StatusBadRequest,
			"message": err.Error(),
		})
		return
	}

	renderService := infra.GetGlobalAppDependencies().RenderService
	preview, err := renderService.RenderBySharingKey(ctx, req.sharingKey, req.template)
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

func parseRenderPreviewRequest(rawURL string, legacySharingKey string, legacyTemplate string) (*renderPreviewRequest, error) {
	rawURL = strings.TrimSpace(rawURL)
	if rawURL == "" {
		sharingKey := strings.TrimSpace(legacySharingKey)
		if sharingKey == "" {
			return nil, errRenderURLMissing
		}
		return &renderPreviewRequest{
			sharingKey: sharingKey,
			template:   legacyTemplate,
		}, nil
	}

	parsedURL, err := url.Parse(rawURL)
	if err != nil || parsedURL.Scheme == "" || parsedURL.Host == "" {
		return nil, fmt.Errorf("%w: must be an absolute share URL", errRenderURLInvalid)
	}

	sharingKey := extractSharingKeyFromShareURL(parsedURL.Path)
	if sharingKey == "" {
		return nil, fmt.Errorf("%w: expected path /s/{sharingKey}", errRenderURLInvalid)
	}

	return &renderPreviewRequest{
		sharingKey: sharingKey,
		template:   parsedURL.Query().Get("m"),
	}, nil
}

func extractSharingKeyFromShareURL(path string) string {
	parts := strings.Split(strings.Trim(path, "/"), "/")
	if len(parts) == 2 && parts[0] == "s" {
		return strings.TrimSpace(parts[1])
	}
	return ""
}
