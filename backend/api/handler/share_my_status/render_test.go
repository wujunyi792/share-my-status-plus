package share_my_status

import (
	"errors"
	"testing"
)

func TestParseRenderPreviewRequestFromURL(t *testing.T) {
	req, err := parseRenderPreviewRequest("https://example.com/s/share-key-123?m=%E6%AD%A3%E5%9C%A8%E5%90%AC%7Btitle%7D&r=https%3A%2F%2Fexample.com", "", "")
	if err != nil {
		t.Fatalf("parseRenderPreviewRequest() error = %v", err)
	}
	if req.sharingKey != "share-key-123" {
		t.Fatalf("sharingKey = %q, want %q", req.sharingKey, "share-key-123")
	}
	if req.template != "正在听{title}" {
		t.Fatalf("template = %q, want %q", req.template, "正在听{title}")
	}
}

func TestParseRenderPreviewRequestLegacyFallback(t *testing.T) {
	req, err := parseRenderPreviewRequest("", " legacy-key ", "hello {title}")
	if err != nil {
		t.Fatalf("parseRenderPreviewRequest() error = %v", err)
	}
	if req.sharingKey != "legacy-key" {
		t.Fatalf("sharingKey = %q, want %q", req.sharingKey, "legacy-key")
	}
	if req.template != "hello {title}" {
		t.Fatalf("template = %q, want %q", req.template, "hello {title}")
	}
}

func TestParseRenderPreviewRequestMissingURLAndSharingKey(t *testing.T) {
	_, err := parseRenderPreviewRequest("", "", "")
	if !errors.Is(err, errRenderURLMissing) {
		t.Fatalf("error = %v, want %v", err, errRenderURLMissing)
	}
}

func TestParseRenderPreviewRequestInvalidURL(t *testing.T) {
	_, err := parseRenderPreviewRequest("://bad", "", "")
	if !errors.Is(err, errRenderURLInvalid) {
		t.Fatalf("error = %v, want %v", err, errRenderURLInvalid)
	}
}

func TestParseRenderPreviewRequestNonSharePath(t *testing.T) {
	_, err := parseRenderPreviewRequest("https://example.com/status/share-key-123?m=hello", "", "")
	if !errors.Is(err, errRenderURLInvalid) {
		t.Fatalf("error = %v, want %v", err, errRenderURLInvalid)
	}
}

func TestParseRenderPreviewRequestExtraSharePathSegments(t *testing.T) {
	_, err := parseRenderPreviewRequest("https://example.com/s/share-key-123/extra?m=hello", "", "")
	if !errors.Is(err, errRenderURLInvalid) {
		t.Fatalf("error = %v, want %v", err, errRenderURLInvalid)
	}
}
