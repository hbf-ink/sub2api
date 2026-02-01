#!/bin/bash
# Sub2API 增量更新脚本
# 用法: ./update.sh [组件]
#
# 示例:
#   ./update.sh          # 更新所有（git pull + 全部 playbook）
#   ./update.sh homarr   # 只更新 Homarr
#   ./update.sh grafana  # 只更新 Grafana
#   ./update.sh pull     # 只拉代码不部署

set -e
cd "$(dirname "$0")"

export SOPS_AGE_SSH_PRIVATE_KEY_FILE=~/.ssh/id_ed25519

case "${1:-all}" in
  pull)
    echo "拉取最新代码..."
    git pull
    ;;
  homarr)
    echo "更新 Homarr..."
    kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: homarr
  namespace: ops
spec:
  template:
    spec:
      containers:
      - name: homarr
        image: ghcr.io/homarr-labs/homarr:v1.50.1
EOF
    kubectl rollout restart deployment/homarr -n ops
    ;;
  grafana)
    echo "更新 Grafana..."
    kubectl rollout restart deployment/grafana -n monitoring
    ;;
  terminal)
    echo "更新 Next Terminal..."
    kubectl rollout restart deployment/next-terminal -n bastion
    ;;
  lldap)
    echo "更新 LLDAP..."
    kubectl rollout restart deployment/lldap -n ops
    ;;
  monitoring)
    echo "更新监控栈..."
    ansible-playbook -i inventory.yml playbooks/05-monitoring.yml
    ;;
  ops-portal)
    echo "更新运维门户..."
    ansible-playbook -i inventory.yml playbooks/08-ops-portal.yml
    ;;
  config)
    echo "更新服务配置..."
    ansible-playbook -i inventory.yml playbooks/09-configure-services.yml
    ;;
  all)
    echo "全量更新..."
    git pull 2>/dev/null || true
    ansible-playbook -i inventory.yml site.yml
    ;;
  *)
    echo "用法: ./update.sh [pull|homarr|grafana|terminal|lldap|monitoring|ops-portal|config|all]"
    exit 1
    ;;
esac

echo "更新完成"
