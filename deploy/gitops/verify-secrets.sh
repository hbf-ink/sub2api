#!/bin/bash
# 验证所有 secrets 是否已替换

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "检查 GitOps 配置中的未替换 Secrets"
echo "========================================="
echo ""

FOUND_ISSUES=0

# 检查所有 YAML 文件中的 CHANGE_ME
while IFS= read -r line; do
    FOUND_ISSUES=$((FOUND_ISSUES + 1))
    echo -e "${RED}✗${NC} $line"
done < <(grep -rn "CHANGE_ME_" . --include="*.yaml" 2>/dev/null || true)

if [ $FOUND_ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓${NC} 所有 secrets 已配置"
else
    echo ""
    echo -e "${YELLOW}警告: 发现 $FOUND_ISSUES 个未配置的 secrets${NC}"
    echo ""
    echo "请使用以下命令生成随机密钥："
    echo "  openssl rand -hex 32  # 生成 64 字符密钥"
    echo "  openssl rand -hex 64  # 生成 128 字符密钥"
    echo ""
    exit 1
fi

echo ""
echo "========================================="
echo "检查必需的配置"
echo "========================================="
echo ""

# 检查域名配置
if grep -q "ops.hbf.ink" auth/ingress.yaml; then
    echo -e "${GREEN}✓${NC} 域名配置正确"
else
    echo -e "${RED}✗${NC} 域名配置错误"
    FOUND_ISSUES=$((FOUND_ISSUES + 1))
fi

# 检查 namespace
for ns in auth monitoring ops; do
    if [ -f "$ns/namespace.yaml" ]; then
        echo -e "${GREEN}✓${NC} Namespace $ns 存在"
    else
        echo -e "${RED}✗${NC} Namespace $ns 缺失"
        FOUND_ISSUES=$((FOUND_ISSUES + 1))
    fi
done

# 检查 kustomization.yaml
for dir in apps auth monitoring ops; do
    if [ -f "$dir/kustomization.yaml" ]; then
        echo -e "${GREEN}✓${NC} $dir/kustomization.yaml 存在"
    else
        echo -e "${RED}✗${NC} $dir/kustomization.yaml 缺失"
        FOUND_ISSUES=$((FOUND_ISSUES + 1))
    fi
done

echo ""
if [ $FOUND_ISSUES -eq 0 ]; then
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}✓ 所有配置检查通过，可以部署！${NC}"
    echo -e "${GREEN}=========================================${NC}"
    exit 0
else
    echo -e "${RED}=========================================${NC}"
    echo -e "${RED}✗ 发现 $FOUND_ISSUES 个问题，请修复后再部署${NC}"
    echo -e "${RED}=========================================${NC}"
    exit 1
fi
