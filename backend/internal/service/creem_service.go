package service

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
)

// CreemService Creem 支付服务
type CreemService struct {
	settingService *SettingService
	userRepo       UserRepository
}

// NewCreemService 创建 Creem 支付服务实例
func NewCreemService(settingService *SettingService, userRepo UserRepository) *CreemService {
	return &CreemService{
		settingService: settingService,
		userRepo:       userRepo,
	}
}

// IsEnabled 检查 Creem 是否启用
func (s *CreemService) IsEnabled(ctx context.Context) bool {
	cfg, err := s.settingService.GetCreemConfig(ctx)
	if err != nil {
		return false
	}
	return cfg.Enabled && cfg.APIKey != "" && cfg.ProductID != ""
}

// GetRateMultiplier 获取充值倍率
func (s *CreemService) GetRateMultiplier(ctx context.Context) float64 {
	cfg, err := s.settingService.GetCreemConfig(ctx)
	if err != nil || cfg.RateMultiplier <= 0 {
		return 10.0
	}
	return cfg.RateMultiplier
}

// CreemCheckoutRequest Creem checkout 请求
type CreemCheckoutRequest struct {
	ProductID  string                 `json:"product_id"`
	SuccessURL string                 `json:"success_url"`
	RequestID  string                 `json:"request_id,omitempty"`
	Metadata   *CreemCheckoutMetadata `json:"metadata,omitempty"`
	Customer   *CreemCheckoutCustomer `json:"customer,omitempty"`
}

// CreemCheckoutMetadata Creem checkout 元数据
type CreemCheckoutMetadata struct {
	UserID int64  `json:"user_id"`
	Email  string `json:"email"`
	Amount int    `json:"amount"` // 金额（分）
}

// CreemCheckoutCustomer Creem checkout 客户信息
type CreemCheckoutCustomer struct {
	Email string `json:"email"`
}

// CreemCheckoutResponse Creem checkout 响应
type CreemCheckoutResponse struct {
	ID          string `json:"id"`
	CheckoutURL string `json:"checkout_url"`
	Status      string `json:"status"`
}

// CreemWebhookPayload Creem webhook 载荷
type CreemWebhookPayload struct {
	ID     string           `json:"id"`
	Object string           `json:"object"`
	Data   CreemWebhookData `json:"data"`
}

// CreemWebhookData Creem webhook 数据
type CreemWebhookData struct {
	Object         CreemCheckoutObject `json:"object"`
	PreviousStatus string              `json:"previous_status,omitempty"`
}

// CreemCheckoutObject Creem checkout 对象
type CreemCheckoutObject struct {
	ID          string                 `json:"id"`
	Status      string                 `json:"status"`
	Mode        string                 `json:"mode"`
	AmountTotal int                    `json:"amount_total"` // 单位：分
	Currency    string                 `json:"currency"`
	Customer    CreemCustomer          `json:"customer"`
	Metadata    map[string]interface{} `json:"metadata"`
}

// CreemCustomer Creem 客户
type CreemCustomer struct {
	ID    string `json:"id"`
	Email string `json:"email"`
}

// CreateCheckoutResult checkout 创建结果
type CreateCheckoutResult struct {
	CheckoutURL string `json:"checkout_url"`
}

// CreateCheckout 创建 Creem checkout session
func (s *CreemService) CreateCheckout(ctx context.Context, userID int64, email string, amountCents int) (*CreateCheckoutResult, error) {
	cfg, err := s.settingService.GetCreemConfig(ctx)
	if err != nil {
		return nil, fmt.Errorf("get creem config: %w", err)
	}

	if !cfg.Enabled || cfg.APIKey == "" || cfg.ProductID == "" {
		return nil, fmt.Errorf("creem payment is not enabled or not configured")
	}

	successURL := cfg.SuccessURL
	if successURL == "" {
		successURL = "https://hbf.ink/redeem?payment=success"
	}

	reqBody := CreemCheckoutRequest{
		ProductID:  cfg.ProductID,
		SuccessURL: successURL,
		RequestID:  fmt.Sprintf("user_%d_%d", userID, amountCents),
		Metadata: &CreemCheckoutMetadata{
			UserID: userID,
			Email:  email,
			Amount: amountCents,
		},
		Customer: &CreemCheckoutCustomer{
			Email: email,
		},
	}

	jsonBody, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	// 测试模式 API key 以 creem_test_ 开头，使用测试 API
	apiURL := "https://api.creem.io/v1/checkouts"
	if strings.HasPrefix(cfg.APIKey, "creem_test_") {
		apiURL = "https://test-api.creem.io/v1/checkouts"
	}

	req, err := http.NewRequestWithContext(ctx, "POST", apiURL, bytes.NewReader(jsonBody))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-api-key", cfg.APIKey)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("send request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		return nil, fmt.Errorf("creem api error: status=%d body=%s", resp.StatusCode, string(body))
	}

	var checkoutResp CreemCheckoutResponse
	if err := json.Unmarshal(body, &checkoutResp); err != nil {
		return nil, fmt.Errorf("unmarshal response: %w", err)
	}

	return &CreateCheckoutResult{
		CheckoutURL: checkoutResp.CheckoutURL,
	}, nil
}

// VerifyWebhookSignature 验证 webhook 签名
func (s *CreemService) VerifyWebhookSignature(ctx context.Context, payload []byte, signature string) bool {
	cfg, err := s.settingService.GetCreemConfig(ctx)
	if err != nil || cfg.WebhookSecret == "" {
		log.Println("[Creem] Warning: webhook_secret not configured, skipping signature verification")
		return true
	}

	// 获取 secret，去掉可能的 whsec_ 前缀
	secret := cfg.WebhookSecret
	secret = strings.TrimPrefix(secret, "whsec_")

	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(payload)
	expectedSig := hex.EncodeToString(mac.Sum(nil))

	// 移除 "sha256=" 前缀（如果存在）
	signature = strings.TrimPrefix(signature, "sha256=")

	log.Printf("[Creem] Signature verification: received=%s expected=%s", signature, expectedSig)

	return hmac.Equal([]byte(expectedSig), []byte(signature))
}

// HandleWebhook 处理 Creem webhook
func (s *CreemService) HandleWebhook(ctx context.Context, payload []byte) error {
	var webhookData CreemWebhookPayload
	if err := json.Unmarshal(payload, &webhookData); err != nil {
		return fmt.Errorf("unmarshal webhook: %w", err)
	}

	log.Printf("[Creem] Webhook received: id=%s object=%s status=%s",
		webhookData.ID, webhookData.Object, webhookData.Data.Object.Status)

	// 只处理 checkout.completed 事件
	if webhookData.Object != "event" || webhookData.Data.Object.Status != "completed" {
		log.Printf("[Creem] Ignoring webhook: object=%s status=%s", webhookData.Object, webhookData.Data.Object.Status)
		return nil
	}

	checkout := webhookData.Data.Object

	// 从 metadata 获取 user_id
	var userID int64
	if metadata := checkout.Metadata; metadata != nil {
		if uid, ok := metadata["user_id"].(float64); ok {
			userID = int64(uid)
		}
	}

	// 如果 metadata 没有 user_id，尝试从 email 查找用户
	if userID == 0 && checkout.Customer.Email != "" {
		user, err := s.userRepo.GetByEmail(ctx, checkout.Customer.Email)
		if err != nil {
			log.Printf("[Creem] User not found by email %s: %v", checkout.Customer.Email, err)
			return fmt.Errorf("user not found: %w", err)
		}
		userID = user.ID
	}

	if userID == 0 {
		return fmt.Errorf("cannot determine user_id from webhook")
	}

	// 计算余额增加量
	// amount_total 是分，转换为美元后乘以倍率
	amountUSD := float64(checkout.AmountTotal) / 100.0
	rateMultiplier := s.GetRateMultiplier(ctx)
	balanceIncrease := amountUSD * rateMultiplier

	log.Printf("[Creem] Updating balance: user_id=%d amount_usd=%.2f multiplier=%.1f balance_increase=%.2f",
		userID, amountUSD, rateMultiplier, balanceIncrease)

	// 更新用户余额
	if err := s.userRepo.UpdateBalance(ctx, userID, balanceIncrease); err != nil {
		return fmt.Errorf("update balance: %w", err)
	}

	log.Printf("[Creem] Balance updated successfully: user_id=%d +%.2f", userID, balanceIncrease)
	return nil
}
