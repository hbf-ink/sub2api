#!/bin/bash
set -e

# Sub2API 节点部署脚本
# 用法: curl -sSL https://raw.githubusercontent.com/hbf-ink/sub2api/main/deploy/scripts/setup-node.sh | bash -s -- [OPTIONS]
# 或: ./setup-node.sh --db-host=xxx --db-pass=xxx --redis-host=localhost --domains="hbf.ink,beta.hbf.ink"

# 默认配置
DB_HOST=""
DB_PORT=5432
DB_USER="neondb_owner"
DB_PASS=""
DB_NAME="neondb"
DB_SSLMODE="require"
REDIS_HOST="localhost"
REDIS_PORT=6379
REDIS_PASS=""
DOMAINS=""
IMAGE_TAG="latest"
JWT_SECRET=""

# 解析参数
for arg in "$@"; do
  case $arg in
    --db-host=*) DB_HOST="${arg#*=}" ;;
    --db-port=*) DB_PORT="${arg#*=}" ;;
    --db-user=*) DB_USER="${arg#*=}" ;;
    --db-pass=*) DB_PASS="${arg#*=}" ;;
    --db-name=*) DB_NAME="${arg#*=}" ;;
    --redis-host=*) REDIS_HOST="${arg#*=}" ;;
    --redis-port=*) REDIS_PORT="${arg#*=}" ;;
    --redis-pass=*) REDIS_PASS="${arg#*=}" ;;
    --domains=*) DOMAINS="${arg#*=}" ;;
    --image-tag=*) IMAGE_TAG="${arg#*=}" ;;
    --jwt-secret=*) JWT_SECRET="${arg#*=}" ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

# 检查必需参数
if [ -z "$DB_HOST" ] || [ -z "$DB_PASS" ] || [ -z "$DOMAINS" ]; then
  echo "Error: --db-host, --db-pass, --domains are required"
  exit 1
fi

# 生成 JWT secret
if [ -z "$JWT_SECRET" ]; then
  JWT_SECRET=$(openssl rand -hex 32)
fi

echo "=== Sub2API Node Setup ==="
echo "DB: $DB_HOST:$DB_PORT/$DB_NAME"
echo "Redis: $REDIS_HOST:$REDIS_PORT"
echo "Domains: $DOMAINS"
echo "Image: ghcr.io/hbf-ink/sub2api:$IMAGE_TAG"
echo ""

# 1. 安装依赖
echo "[1/5] Installing dependencies..."
apt-get update -qq
apt-get install -y -qq podman curl jq

# 2. 安装 Redis (如果是 localhost)
if [ "$REDIS_HOST" = "localhost" ] || [ "$REDIS_HOST" = "127.0.0.1" ]; then
  echo "[2/5] Installing Redis..."
  apt-get install -y -qq redis-server
  systemctl enable redis-server
  systemctl start redis-server
else
  echo "[2/5] Using external Redis: $REDIS_HOST"
fi

# 3. 安装 Caddy
echo "[3/5] Installing Caddy..."
apt-get install -y -qq debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg 2>/dev/null || true
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" | tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null
apt-get update -qq
apt-get install -y -qq caddy

# 4. 配置文件
echo "[4/5] Creating configurations..."
mkdir -p /opt/sub2api

# Caddyfile
cat > /etc/caddy/Caddyfile << EOF
$DOMAINS {
    reverse_proxy localhost:8080
}
EOF

# config.yaml
cat > /opt/sub2api/config.yaml << EOF
server:
  host: 0.0.0.0
  port: 8080
  mode: release
database:
  host: $DB_HOST
  port: $DB_PORT
  user: $DB_USER
  password: $DB_PASS
  dbname: $DB_NAME
  sslmode: $DB_SSLMODE
redis:
  host: $REDIS_HOST
  port: $REDIS_PORT
  password: "$REDIS_PASS"
  db: 0
jwt:
  secret: $JWT_SECRET
  expire_hour: 24
default:
  user_concurrency: 5
  user_balance: 0
  api_key_prefix: sk-
  rate_multiplier: 1
rate_limit:
  requests_per_minute: 60
  burst_size: 10
timezone: Asia/Shanghai
EOF

# 5. 启动服务
echo "[5/5] Starting services..."
systemctl restart caddy

# 停止旧容器
podman stop sub2api 2>/dev/null || true
podman rm sub2api 2>/dev/null || true

# 启动 sub2api
podman run -d \
  --name sub2api \
  --restart always \
  --network host \
  -v /opt/sub2api/config.yaml:/app/config.yaml:ro \
  -e RUN_MODE=standard \
  -e TZ=Asia/Shanghai \
  ghcr.io/hbf-ink/sub2api:$IMAGE_TAG

echo ""
echo "=== Setup Complete ==="
echo "Sub2API is running on port 8080"
echo "Caddy is serving: $DOMAINS"
echo ""
echo "Check status:"
echo "  podman logs sub2api"
echo "  curl -s http://localhost:8080/health"
