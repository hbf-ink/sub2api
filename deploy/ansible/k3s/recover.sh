#!/bin/bash
# Sub2API 远程恢复 - 从任意机器恢复 ops
#
# 前置条件:
#   1. 本机有 SSH 私钥 ~/.ssh/id_ed25519 (用于 SOPS 解密)
#   2. 本机已安装 sshpass
#   3. 已 git clone 本仓库
#
# 用法: 
#   ./recover.sh <ops_ip> <password>                      # 只恢复 ops
#   ./recover.sh <ops_ip> <pass> <prod_ip> <prod_pass>    # 恢复 ops + prod

set -e

OPS_IP="${1:?用法: ./recover.sh <ops_ip> <password> [prod_ip] [prod_password]}"
OPS_PASS="${2:?请提供 ops 密码}"
PROD_IP="${3:-}"
PROD_PASS="${4:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_KEY="$HOME/.ssh/id_ed25519"

echo "=========================================="
echo "Sub2API 远程恢复"
echo "=========================================="
echo "Ops: $OPS_IP"
[ -n "$PROD_IP" ] && echo "Prod: $PROD_IP"
echo ""

# 检查依赖
if ! command -v sshpass &> /dev/null; then
    echo "错误: 请先安装 sshpass"
    exit 1
fi

if [ ! -f "$SSH_KEY" ]; then
    echo "错误: SSH 私钥不存在: $SSH_KEY"
    exit 1
fi

# 清理旧 host key
echo "[1/4] 清理旧 SSH host keys..."
ssh-keygen -R "$OPS_IP" 2>/dev/null || true
[ -n "$PROD_IP" ] && ssh-keygen -R "$PROD_IP" 2>/dev/null || true

# 上传 SSH 密钥和代码
echo "[2/4] 上传文件..."
export SSHPASS="$OPS_PASS"
sshpass -e ssh -o StrictHostKeyChecking=accept-new "ubuntu@$OPS_IP" "mkdir -p ~/.ssh ~/ansible/k3s"
sshpass -e scp "$SSH_KEY" "ubuntu@$OPS_IP:~/.ssh/id_ed25519"
sshpass -e ssh "ubuntu@$OPS_IP" "chmod 600 ~/.ssh/id_ed25519"
sshpass -e scp -r "$SCRIPT_DIR"/* "ubuntu@$OPS_IP:~/ansible/k3s/"

# 如果有 prod，配置 SSH 互信
if [ -n "$PROD_IP" ] && [ -n "$PROD_PASS" ]; then
    echo "[3/4] 配置 prod SSH..."
    OPS_PUBKEY=$(sshpass -e ssh "ubuntu@$OPS_IP" "ssh-keygen -y -f ~/.ssh/id_ed25519")
    
    export SSHPASS="$PROD_PASS"
    sshpass -e ssh -o StrictHostKeyChecking=accept-new "root@$PROD_IP" "mkdir -p ~/.ssh && echo '$OPS_PUBKEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
    
    export SSHPASS="$OPS_PASS"
    sshpass -e ssh "ubuntu@$OPS_IP" "ssh-keyscan -H $PROD_IP >> ~/.ssh/known_hosts 2>/dev/null"
else
    echo "[3/4] 跳过 prod 配置"
fi

# 执行恢复
echo "[4/4] 执行 Ansible..."
export SSHPASS="$OPS_PASS"
if [ -n "$PROD_IP" ]; then
    sshpass -e ssh "ubuntu@$OPS_IP" "cd ~/ansible/k3s && chmod +x local-recover.sh && ./local-recover.sh $PROD_IP"
else
    sshpass -e ssh "ubuntu@$OPS_IP" "cd ~/ansible/k3s && chmod +x local-recover.sh && ./local-recover.sh"
fi

echo ""
echo "=========================================="
echo "恢复完成!"
echo "=========================================="
