package middleware

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"time"

	"share-my-status/internal/database"
	"share-my-status/internal/model"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/common/utils"
	"github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

// SecretKeyAuth Secret Key认证中间件
func SecretKeyAuth() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		secretKey := string(c.GetHeader("X-Secret-Key"))
		if secretKey == "" {
			c.JSON(http.StatusUnauthorized, utils.H{
				"code":    401,
				"message": "Missing X-Secret-Key header",
			})
			c.Abort()
			return
		}

		// 将Secret Key转换为哈希
		hash := sha256.Sum256([]byte(secretKey))
		secretKeyHash := hex.EncodeToString(hash[:])

		// 查询用户
		var user model.User
		err := database.GetDB().Where("secret_key = ?", secretKeyHash).First(&user).Error
		if err != nil {
			if err == gorm.ErrRecordNotFound {
				c.JSON(http.StatusUnauthorized, utils.H{
					"code":    401,
					"message": "Invalid secret key",
				})
			} else {
				logrus.Errorf("Failed to query user by secret key: %v", err)
				c.JSON(http.StatusInternalServerError, utils.H{
					"code":    500,
					"message": "Internal server error",
				})
			}
			c.Abort()
			return
		}

		// 检查用户状态
		if user.Status != 1 {
			c.JSON(http.StatusForbidden, utils.H{
				"code":    403,
				"message": "User account is disabled",
			})
			c.Abort()
			return
		}

		// 将用户信息存储到上下文中
		c.Set("user_id", user.ID)
		c.Set("open_id", user.OpenID)
		c.Set("sharing_key", user.SharingKey)

		c.Next(ctx)
	}
}

// SharingKeyAuth Sharing Key认证中间件
func SharingKeyAuth() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		sharingKey := c.Query("sharingKey")
		if sharingKey == "" {
			c.JSON(http.StatusBadRequest, utils.H{
				"code":    400,
				"message": "Missing sharingKey parameter",
			})
			c.Abort()
			return
		}

		// 查询用户
		var user model.User
		err := database.GetDB().Where("sharing_key = ?", sharingKey).First(&user).Error
		if err != nil {
			if err == gorm.ErrRecordNotFound {
				c.JSON(http.StatusNotFound, utils.H{
					"code":    404,
					"message": "Sharing key not found",
				})
			} else {
				logrus.Errorf("Failed to query user by sharing key: %v", err)
				c.JSON(http.StatusInternalServerError, utils.H{
					"code":    500,
					"message": "Internal server error",
				})
			}
			c.Abort()
			return
		}

		// 检查用户状态
		if user.Status != 1 {
			c.JSON(http.StatusForbidden, utils.H{
				"code":    403,
				"message": "User account is disabled",
			})
			c.Abort()
			return
		}

		// 检查用户设置中的公开授权
		var settings model.UserSettings
		err = database.GetDB().Where("open_id = ?", user.OpenID).First(&settings).Error
		if err != nil && err != gorm.ErrRecordNotFound {
			logrus.Errorf("Failed to query user settings: %v", err)
			c.JSON(http.StatusInternalServerError, utils.H{
				"code":    500,
				"message": "Internal server error",
			})
			c.Abort()
			return
		}

		// 检查公开授权状态
		if publicEnabled, ok := settings.Settings["publicEnabled"].(bool); ok && !publicEnabled {
			c.JSON(http.StatusForbidden, utils.H{
				"code":    403,
				"message": "Public access is disabled",
			})
			c.Abort()
			return
		}

		// 将用户信息存储到上下文中
		c.Set("user_id", user.ID)
		c.Set("open_id", user.OpenID)
		c.Set("sharing_key", user.SharingKey)

		c.Next(ctx)
	}
}

// LarkSignatureAuth 飞书签名验证中间件
func LarkSignatureAuth() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		timestamp := string(c.GetHeader("X-Lark-Request-Timestamp"))
		nonce := string(c.GetHeader("X-Lark-Request-Nonce"))
		signature := string(c.GetHeader("X-Lark-Signature"))

		if timestamp == "" || nonce == "" || signature == "" {
			c.JSON(http.StatusUnauthorized, utils.H{
				"code":    401,
				"message": "Missing Lark signature headers",
			})
			c.Abort()
			return
		}

		// 获取请求体
		body := string(c.Request.Body())

		// 验证签名
		if !verifyLarkSignature(timestamp, nonce, signature, body) {
			c.JSON(http.StatusUnauthorized, utils.H{
				"code":    401,
				"message": "Invalid Lark signature",
			})
			c.Abort()
			return
		}

		c.Next(ctx)
	}
}

// verifyLarkSignature 验证飞书签名
func verifyLarkSignature(timestamp, nonce, signature, body string) bool {
	// 这里应该实现飞书签名验证逻辑
	// 由于需要飞书的AppSecret，这里先返回true
	// 实际实现中应该使用飞书SDK的签名验证方法
	return true
}

// RateLimit 简单的速率限制中间件
func RateLimit(maxRequests int, window time.Duration) app.HandlerFunc {
	// 这里应该实现基于Redis的速率限制
	// 简化版本，实际应该使用滑动窗口或令牌桶算法
	return func(ctx context.Context, c *app.RequestContext) {
		// 检查是否超过限制
		// 这里应该查询Redis中的计数器
		// 简化版本直接通过
		_ = maxRequests
		_ = window

		c.Next(ctx)
	}
}

// CORS CORS中间件
func CORS() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		origin := string(c.Request.Header.Peek("Origin"))
		if origin != "" {
			c.Header("Access-Control-Allow-Origin", origin)
		} else {
			c.Header("Access-Control-Allow-Origin", "*")
		}

		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Secret-Key, X-Lark-Request-Timestamp, X-Lark-Request-Nonce, X-Lark-Signature")
		c.Header("Access-Control-Allow-Credentials", "true")
		c.Header("Access-Control-Max-Age", "86400")

		if string(c.Method()) == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next(ctx)
	}
}

// Logger 日志中间件
func Logger() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		start := time.Now()
		path := string(c.URI().Path())
		raw := string(c.URI().QueryString())

		c.Next(ctx)

		latency := time.Since(start)
		clientIP := c.ClientIP()
		method := string(c.Method())
		statusCode := c.Response.StatusCode()
		bodySize := len(c.Response.Body())

		if raw != "" {
			path = path + "?" + raw
		}

		logrus.WithFields(logrus.Fields{
			"status":    statusCode,
			"latency":   latency,
			"client_ip": clientIP,
			"method":    method,
			"path":      path,
			"body_size": bodySize,
		}).Info("HTTP Request")
	}
}

// Recovery 恢复中间件
func Recovery() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		defer func() {
			if err := recover(); err != nil {
				logrus.Errorf("Panic recovered: %v", err)
				c.JSON(http.StatusInternalServerError, utils.H{
					"code":    500,
					"message": "Internal server error",
				})
				c.Abort()
			}
		}()

		c.Next(ctx)
	}
}
