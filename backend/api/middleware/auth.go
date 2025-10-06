package middleware

import (
	"context"
	"crypto/sha256"
	"fmt"
	"net/http"
	"share-my-status/infra"
	"share-my-status/model"
	"time"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/common/utils"
	"github.com/redis/go-redis/v9"
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

		// 查询用户
		var user model.User
		err := infra.GetGlobalAppDependencies().DB.Where("secret_key = ?", secretKey).First(&user).Error
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
		err := infra.GetGlobalAppDependencies().DB.Where("sharing_key = ?", sharingKey).First(&user).Error
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
		err = infra.GetGlobalAppDependencies().DB.Where("open_id = ?", user.OpenID).First(&settings).Error
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
		if !settings.Settings.Data().PublicEnabled {
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

// RateLimit 滑动窗口限流中间件
func RateLimit(maxRequests int, window time.Duration) app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		clientIP := c.ClientIP()
		userAgent := string(c.UserAgent())

		// 生成限流键（IP + User-Agent的组合）
		limitKey := fmt.Sprintf("rate_limit:%s:%x", clientIP, sha256.Sum256([]byte(userAgent)))

		// 检查是否超过限制
		allowed, err := checkRateLimit(ctx, limitKey, window, maxRequests)
		if err != nil {
			logrus.Errorf("Rate limit check failed: %v", err)
			// 出错时允许通过，避免影响正常服务
			c.Next(ctx)
			return
		}

		if !allowed {
			c.JSON(http.StatusTooManyRequests, utils.H{
				"code":    429,
				"message": "Rate limit exceeded",
			})
			c.Abort()
			return
		}

		c.Next(ctx)
	}
}

// checkRateLimit 检查限流（滑动窗口算法）
func checkRateLimit(ctx context.Context, key string, windowSize time.Duration, maxRequests int) (bool, error) {
	redisClient := infra.GetGlobalAppDependencies().RedisClient
	now := time.Now()
	windowStart := now.Add(-windowSize)

	// 使用Redis的ZREMRANGEBYSCORE清理过期的请求记录
	pipe := redisClient.Pipeline()

	// 清理过期的请求记录
	pipe.ZRemRangeByScore(ctx, key, "0", fmt.Sprintf("%d", windowStart.UnixNano()))

	// 获取当前窗口内的请求数量
	pipe.ZCard(ctx, key)

	// 添加当前请求
	pipe.ZAdd(ctx, key, redis.Z{
		Score:  float64(now.UnixNano()),
		Member: now.UnixNano(),
	})

	// 设置过期时间
	pipe.Expire(ctx, key, windowSize)

	results, err := pipe.Exec(ctx)
	if err != nil {
		return false, err
	}

	// 获取当前请求数量
	currentCount := results[1].(*redis.IntCmd).Val()

	// 如果当前请求数量超过限制，移除刚添加的请求
	if currentCount > int64(maxRequests) {
		redisClient.ZRem(ctx, key, now.UnixNano())
		return false, nil
	}

	return true, nil
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
