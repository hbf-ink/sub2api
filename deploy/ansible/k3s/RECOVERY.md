# Sub2API K3s 集群恢复指南

## 新架构说明

**基础设施层（Ansible 管理）：**
- K3s 集群
- WireGuard VPN
- cert-manager
- ArgoCD

**应用层（ArgoCD/GitOps 管理）：**
- 认证栈：LLDAP + Authelia（单点登录）
- 监控栈：Grafana + Prometheus + Loki + Tempo
- 运维栈：Homarr + Next Terminal
- 业务应用：Sub2API

## 快速恢复

### 方式一：在 ops 机器上直接恢复（推荐）

```bash
# 1. SSH 到新的 ops 机器
ssh ubuntu@<ops_ip>

# 2. 恢复 SSH 私钥（用于 SOPS 解密）
mkdir -p ~/.ssh
# 从安全位置恢复私钥
chmod 600 ~/.ssh/id_ed25519

# 3. 克隆仓库
git clone https://github.com/hbf-ink/sub2api.git
cd sub2api/deploy/ansible/k3s

# 4. 安装依赖
sudo apt update
sudo apt install -y ansible sops

# 5. 执行一键恢复
ansible-playbook -i inventory.yml site.yml

# ArgoCD 会自动部署所有应用
```

恢复完成后访问：
- **ArgoCD**: https://ops.hbf.ink/argocd (查看应用部署状态)
- **Authelia**: https://ops.hbf.ink/authelia (单点登录)
- **Homarr**: https://ops.hbf.ink (运维首页)
- **Grafana**: https://ops.hbf.ink/grafana (监控)

### 方式二：从本地机器远程恢复

```bash
# 1. 克隆仓库
git clone https://github.com/hbf-ink/sub2api.git
cd sub2api/deploy/ansible/k3s

# 2. 确保本机有 SSH 私钥 ~/.ssh/id_ed25519

# 3. 配置 inventory.yml 中的服务器 IP

# 4. 执行部署
ansible-playbook -i inventory.yml site.yml
```

## SSH 私钥备份

**⚠️ 重要**: SSH 私钥 `~/.ssh/id_ed25519` 是解密 secrets 的唯一密钥！

### 备份私钥

```bash
# 方式A: 加密备份到 R2
gpg --symmetric --cipher-algo AES256 ~/.ssh/id_ed25519
rclone copy ~/.ssh/id_ed25519.gpg r2:hbf-backup/keys/

# 方式B: 离线备份
# 复制到 U 盘、打印二维码等物理介质
```

### 恢复私钥

```bash
# 从 R2 恢复
rclone copy r2:hbf-backup/keys/id_ed25519.gpg ~/.ssh/
gpg --decrypt ~/.ssh/id_ed25519.gpg > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
rm ~/.ssh/id_ed25519.gpg
```

## ArgoCD 管理

### 查看应用状态

```bash
# 获取 ArgoCD 初始密码
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 登录 ArgoCD
# https://ops.hbf.ink/argocd
# 用户名: admin
# 密码: 上面命令输出
```

### 手动同步应用

```bash
# 通过 UI
访问 ArgoCD UI → 选择应用 → 点击 SYNC

# 通过 CLI
kubectl port-forward svc/argocd-server -n argocd 8080:443
argocd login localhost:8080
argocd app sync auth
argocd app sync monitoring
argocd app sync ops
```

### 修改应用配置

所有应用配置在 `deploy/gitops/` 目录：

```bash
# 1. 修改配置文件
vim deploy/gitops/auth/lldap.yaml

# 2. 提交到 Git
git add deploy/gitops/auth/lldap.yaml
git commit -m "更新 LLDAP 配置"
git push

# 3. ArgoCD 自动检测并部署（或手动同步）
```

## Secrets 管理

### 更新 Secrets

所有 secrets 在对应的 YAML 文件中标注为 `CHANGE_ME_*`：

```bash
# 1. 编辑 secrets
vim deploy/gitops/auth/lldap.yaml
vim deploy/gitops/auth/authelia.yaml
vim deploy/gitops/ops/homarr.yaml

# 2. 生成随机密钥
openssl rand -hex 32  # 64 字符
openssl rand -hex 64  # 128 字符

# 3. 替换所有 CHANGE_ME_* 为实际值

# 4. 提交并推送
git add deploy/gitops/
git commit -m "更新 secrets"
git push
```

### 使用 Sealed Secrets（推荐）

为了避免明文 secrets 进 Git，建议使用 Sealed Secrets：

```bash
# 安装 Sealed Secrets Controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.2/controller.yaml

# 安装 kubeseal CLI
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.2/kubeseal-linux-amd64
chmod +x kubeseal-linux-amd64
sudo mv kubeseal-linux-amd64 /usr/local/bin/kubeseal

# 加密 Secret
kubectl create secret generic lldap-secrets \
  --from-literal=LLDAP_JWT_SECRET=xxx \
  --from-literal=LLDAP_LDAP_USER_PASS=xxx \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > deploy/gitops/auth/lldap-sealed-secret.yaml

# 更新 lldap.yaml 使用 SealedSecret
```

## 单点登录（Authelia）

### 配置说明

Authelia 已配置为所有服务的统一认证入口：

- **LLDAP**: 用户数据库
- **Authelia**: 认证服务
- **Grafana**: 通过 Authelia ForwardAuth 认证
- **Homarr**: 通过 OIDC 与 Authelia 集成
- **Next Terminal**: 通过 Authelia ForwardAuth 认证

### 登录流程

1. 访问任意受保护服务（如 https://ops.hbf.ink/grafana）
2. 自动跳转到 Authelia 登录页
3. 输入 LDAP 账号密码（calvinhong / 密码）
4. 登录成功后自动跳回原服务
5. 访问其他服务无需重复登录（SSO）

### 添加新用户

```bash
# 在 LLDAP 中创建用户
https://ops.hbf.ink/lldap

# 新用户自动可以登录所有服务
```

## 增量更新

只更新某个服务：

```bash
# 方式A: 通过 ArgoCD UI 手动同步

# 方式B: 修改配置后 Git 推送（ArgoCD 自动同步）
vim deploy/gitops/monitoring/grafana.yaml
git commit -am "更新 Grafana 配置"
git push

# 方式C: 通过 kubectl
kubectl apply -k deploy/gitops/monitoring/
```

## 灾难恢复测试

定期测试恢复流程：

```bash
# 1. 删除所有应用
argocd app delete auth monitoring ops --cascade

# 2. 重新同步
argocd app sync apps  # App of Apps 会重建所有应用

# 3. 验证所有服务正常
curl -k https://ops.hbf.ink/authelia/api/health
curl -k https://ops.hbf.ink/grafana/api/health
```

## 监控告警

访问 Grafana 查看：
- **集群健康**: Node Exporter 面板
- **应用状态**: Pod 监控面板
- **日志**: Loki 日志查询

## 常见问题

### ArgoCD 应用一直 OutOfSync

```bash
# 检查 Git 仓库连接
argocd repo list

# 刷新应用
argocd app get auth --refresh

# 查看同步失败原因
argocd app get auth
```

### Authelia 无法连接 LLDAP

```bash
# 检查 LLDAP 状态
kubectl get pods -n auth
kubectl logs -n auth deployment/lldap

# 检查 Service
kubectl get svc -n auth lldap

# 测试连接
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- sh
curl http://lldap.auth.svc.cluster.local:17170
```

### 服务白屏/无法访问

```bash
# 检查 Ingress
kubectl get ingress -A

# 检查中间件
kubectl get middleware -A

# 查看 Traefik 日志
kubectl logs -n kube-system deployment/traefik
```

## 联系方式

如需支持，请查看：
- GitHub Issues: https://github.com/hbf-ink/sub2api/issues
- ArgoCD 文档: https://argo-cd.readthedocs.io/
- Authelia 文档: https://www.authelia.com/
