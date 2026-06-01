package share_my_status

import (
	"testing"

	"share-my-status/infra/config"
)

func TestBuildClientResourcesResponse(t *testing.T) {
	app := &config.AppConfig{
		UserDocURL:            "https://example.com/docs",
		FeishuSignatureDIYURL: "https://magic.solutionsuite.cn/diy?sharingKey={SharingKey}",
	}

	resp := buildClientResourcesResponse(app, "preview-sharing-key")
	if resp.UserDocURL != "https://example.com/docs" {
		t.Fatalf("UserDocURL = %q, want docs URL", resp.UserDocURL)
	}
	if resp.FeishuSignatureDIYURL != "https://magic.solutionsuite.cn/diy?sharingKey=preview-sharing-key" {
		t.Fatalf("FeishuSignatureDIYURL = %q, want replaced DIY URL", resp.FeishuSignatureDIYURL)
	}
}
