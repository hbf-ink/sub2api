package routes

import (
	"github.com/Wei-Shaw/sub2api/internal/handler"
	"github.com/Wei-Shaw/sub2api/internal/server/middleware"

	"github.com/gin-gonic/gin"
)

// RegisterCreemRoutes 注册 Creem 支付相关路由
func RegisterCreemRoutes(
	r *gin.Engine,
	v1 *gin.RouterGroup,
	h *handler.Handlers,
	jwtAuth middleware.JWTAuthMiddleware,
) {
	// 公开接口：获取支付状态
	creem := v1.Group("/creem")
	{
		creem.GET("/status", h.Creem.GetStatus)
	}

	// 需要认证的接口
	authenticated := v1.Group("/creem")
	authenticated.Use(gin.HandlerFunc(jwtAuth))
	{
		authenticated.POST("/checkout", h.Creem.CreateCheckout)
	}

	// Webhook 接口（无需认证，由 Creem 签名验证）
	webhook := v1.Group("/webhook")
	{
		webhook.POST("/creem", h.Creem.HandleWebhook)
	}
}
