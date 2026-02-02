# Sub2API GitOps 配置

这个目录包含所有由 ArgoCD 管理的应用配置。

## 架构

```
基础设施层 (Ansible)          应用层 (ArgoCD/GitOps)
├─ K3s 集群                   ├─ auth/          # LLDAP + Authelia (SSO)
├─ WireGuard VPN              ├─ monitoring/    # Grafana + Prometheus + Loki + Tempo  
├─ cert-manager               ├─ ops/           # Homarr + Next Terminal
└─ ArgoCD                     └─ business/      # Sub2API (待添加)
```

## 目录结构

```
deploy/gitops/
├── apps/                    # ArgoCD Application 定义 (App of Apps 模式)
│   ├── kustomization.yaml
│   ├── auth.yaml           # 认证栈应用定义
│   ├── monitoring.yaml     # 监控栈应用定义
│   └── ops.yaml            # 运维栈应用定义
├── auth/                    # 认证栈配置
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── lldap.yaml          # LDAP 用户目录
│   ├── authelia.yaml       # 单点登录
│   └── ingress.yaml        # 认证相关 Ingress + Middleware
├── monitoring/              # 监控栈配置
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── prometheus.yaml     # 指标收集
│   ├── loki.yaml           # 日志聚合
│   ├── tempo.yaml          # 链路追踪
│   ├── grafana.yaml        # 可视化
│   └── ingress.yaml        # 监控 Ingress
├── ops/                     # 运维栈配置
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── homarr.yaml         # 运维首页
│   ├── next-terminal.yaml  # 堡垒机
│   └── ingress.yaml        # 运维 Ingress
└── business/                # 业务应用 (待添加)
    └── sub2api.yaml
```

## 部署流程

### 1. 基础设施部署

```bash
cd deploy/ansible/k3s
ansible-playbook -i inventory.yml site.yml
```

这会部署：
- K3s 集群
- ArgoCD

### 2. ArgoCD 自动部署应用

ArgoCD 会自动从 Git 拉取配置并部署所有应用。查看进度：

```bash
# 获取 ArgoCD 密码
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 访问 ArgoCD UI
https://ops.hbf.ink/argocd
```

## 修改配置

### 方式一：GitOps（推荐）

```bash
# 1. 编辑配置
vim deploy/gitops/auth/lldap.yaml

# 2. 提交并推送
git add deploy/gitops/auth/lldap.yaml
git commit -m "更新 LLDAP 配置"
git push

# 3. ArgoCD 自动检测变更并同步（约 3 分钟）
# 或手动同步: argocd app sync auth
```

### 方式二：kubectl（临时测试）

```bash
# 直接应用（不会进 Git，重启后丢失）
kubectl apply -k deploy/gitops/auth/
```

## Secrets 管理

⚠️ **所有 secrets 标注为 `CHANGE_ME_*`，部署前必须替换！**

### 需要修改的 Secrets

1. **LLDAP** (`deploy/gitops/auth/lldap.yaml`)
   - `LLDAP_JWT_SECRET`: 至少 32 字符
   - `LLDAP_LDAP_USER_PASS`: 管理员密码

2. **Authelia** (`deploy/gitops/auth/authelia.yaml`)
   - `JWT_SECRET`: 64+ 字符
   - `SESSION_SECRET`: 64+ 字符
   - `STORAGE_ENCRYPTION_KEY`: 64+ 字符
   - `LDAP_PASSWORD`: 与 LLDAP 管理员密码一致

3. **Homarr** (`deploy/gitops/ops/homarr.yaml`)
   - `SECRET_ENCRYPTION_KEY`: 64 hex 字符
   - `AUTH_SECRET`: 64 hex 字符
   - `AUTH_OIDC_CLIENT_SECRET`: Authelia OIDC 客户端密钥

### 生成随机密钥

```bash
# 32 字符 hex (64 字符)
openssl rand -hex 32

# 64 字符 hex (128 字符)
openssl rand -hex 64
```

### 使用 Sealed Secrets（可选，更安全）

避免明文 secrets 进 Git：

```bash
# 1. 安装 Sealed Secrets
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.2/controller.yaml

# 2. 创建 SealedSecret
echo -n "my-secret-value" | kubectl create secret generic my-secret \
  --dry-run=client --from-file=key=/dev/stdin -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml

# 3. 提交到 Git
git add sealed-secret.yaml
```

## 单点登录 (Authelia)

### 工作原理

```
用户访问服务 → Traefik → Authelia 检查 → 已登录？
                            ├─ 是 → 直接访问服务
                            └─ 否 → 跳转 Authelia 登录页
                                    ↓
                            用户登录 → 记住会话 → 返回原服务
```

### 受保护的服务

所有服务通过 Authelia ForwardAuth 中间件保护：
- Grafana
- LLDAP
- Next Terminal
- Homarr (通过 OIDC)

### 添加新服务到 SSO

在 Ingress 中添加中间件：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-service
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: auth-authelia@kubernetescrd
spec:
  # ...
```

## 应用访问地址

| 服务 | 地址 | 用途 |
|------|------|------|
| ArgoCD | https://ops.hbf.ink/argocd | GitOps 部署管理 |
| Authelia | https://ops.hbf.ink/authelia | 单点登录 |
| Homarr | https://ops.hbf.ink | 运维首页 |
| Grafana | https://ops.hbf.ink/grafana | 监控可视化 |
| LLDAP | https://ops.hbf.ink/lldap | 用户管理 |
| Next Terminal | https://ops.hbf.ink/terminal | 堡垒机 |

## 常用命令

```bash
# 查看所有应用状态
argocd app list

# 同步单个应用
argocd app sync auth

# 同步所有应用
argocd app sync -l app.kubernetes.io/instance=apps

# 查看应用详情
argocd app get monitoring

# 查看应用日志
kubectl logs -n monitoring deployment/grafana

# 重启应用
kubectl rollout restart deployment/grafana -n monitoring
```

## 故障排查

### ArgoCD 应用 OutOfSync

```bash
# 检查差异
argocd app diff auth

# 强制刷新
argocd app get auth --refresh --hard-refresh

# 同步
argocd app sync auth --prune --force
```

### Pod 启动失败

```bash
# 查看 Pod 状态
kubectl get pods -n auth

# 查看日志
kubectl logs -n auth deployment/lldap

# 查看事件
kubectl describe pod -n auth <pod-name>
```

### Ingress 无法访问

```bash
# 检查 Ingress
kubectl get ingress -A

# 检查 Middleware
kubectl get middleware -A

# 查看 Traefik 日志
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
```

## 参考文档

- [ArgoCD 文档](https://argo-cd.readthedocs.io/)
- [Authelia 文档](https://www.authelia.com/)
- [Kustomize 文档](https://kustomize.io/)
- [Traefik 文档](https://doc.traefik.io/traefik/)
