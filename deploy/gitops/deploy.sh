#!/bin/bash
# 一键部署 GitOps 架构到 K3s 集群

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "Sub2API GitOps 部署脚本"
echo "========================================="
echo ""

# 检查是否在正确的目录
if [ ! -f "verify-secrets.sh" ]; then
    echo "错误: 请在 deploy/gitops/ 目录下运行此脚本"
    exit 1
fi

# 步骤 1: 验证配置
echo -e "${YELLOW}步骤 1/4: 验证配置${NC}"
bash verify-secrets.sh
echo ""

# 步骤 2: 检查 Git 状态
echo -e "${YELLOW}步骤 2/4: 检查 Git 状态${NC}"
cd ../..
if [ -n "$(git status --porcelain deploy/gitops)" ]; then
    echo "警告: deploy/gitops/ 目录有未提交的更改"
    echo ""
    git status deploy/gitops
    echo ""
    read -p "是否提交并推送到 GitHub? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git add deploy/gitops/
        git commit -m "update: GitOps 配置"
        git push
        echo -e "${GREEN}✓ 已推送到 GitHub${NC}"
    else
        echo "请手动提交并推送后再部署"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Git 状态正常${NC}"
fi
cd deploy/gitops
echo ""

# 步骤 3: 部署到 K3s
echo -e "${YELLOW}步骤 3/4: 部署 ArgoCD${NC}"
echo "注意: 需要先部署基础设施层（Ansible）"
echo "请在 ops 服务器上执行:"
echo ""
echo "  cd ~/ansible/k3s"
echo "  git pull"
echo "  SOPS_AGE_SSH_PRIVATE_KEY_FILE=~/.ssh/id_ed25519 \\"
echo "    ansible-playbook -i inventory.yml playbooks/10-argocd.yml"
echo ""
read -p "是否已完成 ArgoCD 部署? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "请先部署 ArgoCD"
    exit 1
fi
echo ""

# 步骤 4: 检查应用状态
echo -e "${YELLOW}步骤 4/4: 检查应用状态${NC}"
echo "请在 ops 服务器上执行以下命令检查:"
echo ""
echo "  # 查看 ArgoCD 应用"
echo "  kubectl get applications -n argocd"
echo ""
echo "  # 查看所有 Pod"
echo "  kubectl get pods -A"
echo ""
echo "  # 获取 ArgoCD 密码"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret \\"
echo "    -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "访问地址:"
echo "  ArgoCD:   https://ops.hbf.ink/argocd"
echo "  Authelia: https://ops.hbf.ink/authelia"
echo "  Homarr:   https://ops.hbf.ink"
echo "  Grafana:  https://ops.hbf.ink/grafana"
echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}部署完成！${NC}"
echo -e "${GREEN}=========================================${NC}"
