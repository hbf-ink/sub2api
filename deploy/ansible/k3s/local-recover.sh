#!/bin/bash
# Sub2API 本地恢复 - 在 ops 机器上运行
# 
# 前置条件:
#   1. SSH 私钥 ~/.ssh/id_ed25519 (用于 SOPS 解密)
#   2. git clone 本仓库
#
# 用法: 
#   ./local-recover.sh              # 只部署 ops
#   ./local-recover.sh <prod_ip>    # 部署 ops + prod

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROD_IP="${1:-}"
OPS_IP=$(hostname -I | awk '{print $1}')

echo "=========================================="
echo "Sub2API 本地恢复"
echo "=========================================="

# 检查 SSH 私钥
if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "错误: SSH 私钥不存在 ~/.ssh/id_ed25519"
    echo "请先恢复私钥 (用于 SOPS 解密)"
    exit 1
fi

# 生成 inventory
echo "[1/2] 生成 inventory..."
if [ -n "$PROD_IP" ]; then
cat > "$SCRIPT_DIR/inventory.yml" << EOF
all:
  vars:
    ansible_user: ubuntu
    ansible_ssh_common_args: '-o StrictHostKeyChecking=accept-new'
  children:
    ops:
      hosts:
        ops-tokyo-01:
          ansible_host: $OPS_IP
          node_role: ops
          wireguard_ip: 10.10.0.1
    prod:
      hosts:
        prod-tokyo-01:
          ansible_host: $PROD_IP
          ansible_user: root
          node_role: prod
          wireguard_ip: 10.10.0.2
EOF
else
cat > "$SCRIPT_DIR/inventory.yml" << EOF
all:
  vars:
    ansible_user: ubuntu
    ansible_ssh_common_args: '-o StrictHostKeyChecking=accept-new'
  children:
    ops:
      hosts:
        ops-tokyo-01:
          ansible_host: $OPS_IP
          node_role: ops
          wireguard_ip: 10.10.0.1
    prod:
      hosts: {}
EOF
fi

# 执行部署
echo "[2/2] 执行 Ansible..."
cd "$SCRIPT_DIR"
export SOPS_AGE_SSH_PRIVATE_KEY_FILE=~/.ssh/id_ed25519

ansible-playbook -i inventory.yml site.yml

if [ -n "$PROD_IP" ]; then
    ansible-playbook -i inventory.yml add-prod.yml
fi

echo ""
echo "=========================================="
echo "恢复完成!"
echo "=========================================="
echo "访问: https://ops.hbf.ink"
echo "用户: calvinhong"
echo "=========================================="
