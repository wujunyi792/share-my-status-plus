package share_my_status

import (
	"context"
	"strings"

	"share-my-status/infra"
	"share-my-status/infra/config"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/protocol/consts"
)

type ClientResourcesResponse struct {
	UserDocURL            string `json:"userDocUrl,omitempty"`
	FeishuSignatureDIYURL string `json:"feishuSignatureDiyUrl,omitempty"`
}

// ClientResources returns user-specific links shown by desktop clients.
// @router /api/v1/client/resources [GET]
func ClientResources(ctx context.Context, c *app.RequestContext) {
	sharingKey, ok := c.Get("sharing_key")
	if !ok {
		c.JSON(consts.StatusUnauthorized, map[string]any{
			"code":    consts.StatusUnauthorized,
			"message": "Unauthorized",
		})
		return
	}

	c.JSON(consts.StatusOK, buildClientResourcesResponse(&infra.GetGlobalAppDependencies().Config.App, sharingKey.(string)))
}

func buildClientResourcesResponse(app *config.AppConfig, sharingKey string) ClientResourcesResponse {
	return ClientResourcesResponse{
		UserDocURL:            replaceSharingKey(app.UserDocURL, sharingKey),
		FeishuSignatureDIYURL: replaceSharingKey(app.FeishuSignatureDIYURL, sharingKey),
	}
}

func replaceSharingKey(template string, sharingKey string) string {
	if strings.TrimSpace(template) == "" {
		return ""
	}
	return strings.ReplaceAll(template, "{SharingKey}", sharingKey)
}
