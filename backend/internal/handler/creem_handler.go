package handler

import (
	"io"
	"log"

	"github.com/Wei-Shaw/sub2api/internal/pkg/response"
	middleware2 "github.com/Wei-Shaw/sub2api/internal/server/middleware"
	"github.com/Wei-Shaw/sub2api/internal/service"

	"github.com/gin-gonic/gin"
)

// CreemHandler handles Creem payment-related requests
type CreemHandler struct {
	creemService *service.CreemService
	userService  *service.UserService
}

// NewCreemHandler creates a new CreemHandler
func NewCreemHandler(creemService *service.CreemService, userService *service.UserService) *CreemHandler {
	return &CreemHandler{
		creemService: creemService,
		userService:  userService,
	}
}

// CheckoutRequest 创建支付请求
type CheckoutRequest struct {
	Amount int `json:"amount" binding:"required,min=1,max=10000"` // 金额（美元，整数）
}

// CheckoutResponse 支付响应
type CheckoutResponse struct {
	CheckoutURL string `json:"checkout_url"`
}

// GetStatusResponse 支付状态响应
type GetStatusResponse struct {
	Enabled        bool    `json:"enabled"`
	RateMultiplier float64 `json:"rate_multiplier"`
}

// GetStatus 获取支付状态
// GET /api/v1/creem/status
func (h *CreemHandler) GetStatus(c *gin.Context) {
	response.Success(c, GetStatusResponse{
		Enabled:        h.creemService.IsEnabled(),
		RateMultiplier: h.creemService.GetRateMultiplier(),
	})
}

// CreateCheckout 创建支付会话
// POST /api/v1/creem/checkout
func (h *CreemHandler) CreateCheckout(c *gin.Context) {
	subject, ok := middleware2.GetAuthSubjectFromContext(c)
	if !ok {
		response.Unauthorized(c, "User not authenticated")
		return
	}

	var req CheckoutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	// 获取用户信息
	user, err := h.userService.GetProfile(c.Request.Context(), subject.UserID)
	if err != nil {
		response.ErrorFrom(c, err)
		return
	}

	// 创建 Creem checkout session
	// amount 是美元整数，转换为分
	result, err := h.creemService.CreateCheckout(c.Request.Context(), subject.UserID, user.Email, req.Amount*100)
	if err != nil {
		log.Printf("[Creem] CreateCheckout error: %v", err)
		response.InternalError(c, "Failed to create checkout session")
		return
	}

	response.Success(c, CheckoutResponse{
		CheckoutURL: result.CheckoutURL,
	})
}

// HandleWebhook 处理 Creem webhook
// POST /api/v1/webhook/creem
func (h *CreemHandler) HandleWebhook(c *gin.Context) {
	payload, err := io.ReadAll(c.Request.Body)
	if err != nil {
		log.Printf("[Creem] Failed to read webhook body: %v", err)
		c.JSON(400, gin.H{"error": "failed to read body"})
		return
	}

	// 验证签名
	signature := c.GetHeader("creem-signature")
	if !h.creemService.VerifyWebhookSignature(payload, signature) {
		log.Printf("[Creem] Invalid webhook signature")
		c.JSON(401, gin.H{"error": "invalid signature"})
		return
	}

	// 处理 webhook
	if err := h.creemService.HandleWebhook(c.Request.Context(), payload); err != nil {
		log.Printf("[Creem] Webhook processing error: %v", err)
		c.JSON(500, gin.H{"error": "webhook processing failed"})
		return
	}

	c.JSON(200, gin.H{"status": "ok"})
}
