# GitOps 部署验证清单

## 部署前检查

### 1. Secrets 配置检查

⚠️ **所有标记为 `CHANGE_ME_*` 的值都必须替换！**

运行以下命令检查：

```bash
cd C:\Users\calvin\hbf-sub2api\deploy\gitops
grep -r "CHANGE_ME_" .
```

**必须修改的 Secrets：**

- [ ] `auth/lldap.yaml`
  - [ ] `LLDAP_JWT_SECRET` (32+ 字符)
  - [ ] `LLDAP_LDAP_USER_PASS` (管理员密码)

- [ ] `auth/authelia.yaml`
  - [ ] `JWT_SECRET` (64+ 字符)
  - [ ] `SESSION_SECRET` (64+ 字符)
  - [ ] `STORAGE_ENCRYPTION_KEY` (64+ 字符)
  - [ ] `LDAP_PASSWORD` (与 LLDAP 管理员密码一致)

- [ ] `ops/homarr.yaml`
  - [ ] `SECRET_ENCRYPTION_KEY` (64 hex 字符)
  - [ ] `AUTH_SECRET` (64 hex 字符)
  - [ ] `AUTH_OIDC_CLIENT_SECRET` (需在 Authelia 配置对应)

**生成随机密钥：**

```bash
# 生成各种长度的随机密钥
openssl rand -hex 16  # 32 字符
openssl rand -hex 32  # 64 字符
openssl rand -hex 64  # 128 字符
```

### 2. Git 配置检查

- [ ] 所有文件已提交到 Git
- [ ] 已推送到 GitHub
- [ ] GitHub 仓库地址正确：`https://github.com/hbf-ink/sub2api.git`

```bash
cd C:\Users\calvin\hbf-sub2api
git status
git remote -v
```

### 3. 基础设施检查

- [ ] ops 服务器可 SSH 访问
- [ ] SSH 私钥 `~/.ssh/id_ed25519` 存在
- [ ] SOPS 可以解密 `secrets.enc.yml`

```bash
# 测试 SSH
ssh ubuntu@43.163.241.60 "echo OK"

# 测试 SOPS
cd C:\Users\calvin\hbf-sub2api\deploy\ansible\k3s
wsl bash -c "SOPS_AGE_SSH_PRIVATE_KEY_FILE=~/.ssh/id_ed25519 sops -d secrets.enc.yml | head -5"
```

### 4. 域名和证书检查

- [ ] `ops.hbf.ink` DNS 已配置指向 ops 服务器
- [ ] cert-manager 已安装（`10-argocd.yml` 会检查）

## 部署步骤

### 步骤 1: 提交代码

```bash
cd C:\Users\calvin\hbf-sub2api

# 查看变更
git status

# 添加所有新文件
git add deploy/gitops/
git add deploy/ansible/k3s/playbooks/10-argocd.yml
git add deploy/ansible/k3s/site.yml
git add deploy/ansible/k3s/RECOVERY.md

# 提交
git commit -m "feat: 迁移到 ArgoCD + Authelia SSO 架构"

# 推送
git push
```

### 步骤 2: 部署 ArgoCD

```bash
# SSH 到 ops 服务器
ssh ubuntu@43.163.241.60

# 进入目录
cd ~/ansible/k3s  # 如果不存在，先 git clone

# 拉取最新代码
git pull

# 部署 ArgoCD
SOPS_AGE_SSH_PRIVATE_KEY_FILE=~/.ssh/id_ed25519 \
  ansible-playbook -i inventory.yml playbooks/10-argocd.yml
```

预期输出：
```
PLAY RECAP ***************
ops-tokyo-01  : ok=X  changed=Y  unreachable=0  failed=0
```

### 步骤 3: 获取 ArgoCD 密码

```bash
# 在 ops 服务器上执行
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

记录密码：`________________`

### 步骤 4: 访问 ArgoCD UI

1. 打开浏览器访问：https://ops.hbf.ink/argocd
2. 用户名：`admin`
3. 密码：（步骤 3 的输出）

### 步骤 5: 检查应用同步状态

在 ArgoCD UI 中应该看到：
- [ ] `apps` - Synced & Healthy
- [ ] `auth` - Syncing/Synced
- [ ] `monitoring` - Syncing/Synced
- [ ] `ops` - Syncing/Synced

**首次同步可能需要 5-10 分钟**

### 步骤 6: 等待所有应用部署完成

```bash
# 查看所有 Pod 状态
kubectl get pods -A

# 应该看到这些 namespace:
# - argocd
# - auth (lldap, authelia)
# - monitoring (prometheus, loki, tempo, grafana)
# - ops (homarr, next-terminal, guacd)
```

### 步骤 7: 验证服务访问

- [ ] https://ops.hbf.ink/argocd - ArgoCD UI
- [ ] https://ops.hbf.ink/authelia - Authelia 登录页
- [ ] https://ops.hbf.ink - Homarr (应跳转到 Authelia 登录)
- [ ] https://ops.hbf.ink/grafana - Grafana (应跳转到 Authelia 登录)
- [ ] https://ops.hbf.ink/lldap - LLDAP (应跳转到 Authelia 登录)
- [ ] https://ops.hbf.ink/terminal - Next Terminal (应跳转到 Authelia 登录)

### 步骤 8: 测试单点登录

1. 访问 https://ops.hbf.ink/grafana
2. 应自动跳转到 https://ops.hbf.ink/authelia
3. 输入账号密码：`calvinhong` / `<LLDAP 密码>`
4. 登录成功后跳回 Grafana
5. **无需重新登录**直接访问其他服务（如 LLDAP、Next Terminal）

## 故障排查

### ArgoCD 无法访问

```bash
# 检查 ArgoCD Pod
kubectl get pods -n argocd

# 检查 Ingress
kubectl get ingress -n argocd

# 查看日志
kubectl logs -n argocd deployment/argocd-server
```

### 应用一直 OutOfSync

```bash
# 检查 Git 仓库连接
kubectl get secret -n argocd
kubectl logs -n argocd deployment/argocd-repo-server

# 手动触发同步
kubectl patch app auth -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### Authelia 无法连接 LLDAP

```bash
# 检查 LLDAP Pod
kubectl get pods -n auth -l app=lldap

# 检查 Service DNS
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://lldap.auth.svc.cluster.local:17170

# 查看 Authelia 日志
kubectl logs -n auth deployment/authelia | grep -i ldap
```

### 服务跳转登录后白屏

```bash
# 检查 Middleware
kubectl get middleware -A

# 查看 Traefik 日志
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik | tail -50

# 检查 Ingress annotations
kubectl get ingress -n monitoring grafana-ingress -o yaml
```

### Secret 未生效

```bash
# 检查 Secret 是否创建
kubectl get secrets -n auth

# 查看 Secret 内容（base64 解码）
kubectl get secret lldap-secrets -n auth -o jsonpath='{.data.LLDAP_JWT_SECRET}' | base64 -d

# 重启 Pod 使新 Secret 生效
kubectl rollout restart deployment/lldap -n auth
```

## 回滚方案

如果部署失败，快速回滚到当前运行的版本：

```bash
# 删除 ArgoCD 和所有应用
kubectl delete namespace argocd auth monitoring ops

# 使用旧的 Ansible playbooks 重新部署
cd ~/ansible/k3s
git checkout <old-commit>
SOPS_AGE_SSH_PRIVATE_KEY_FILE=~/.ssh/id_ed25519 \
  ansible-playbook -i inventory.yml playbooks/05-monitoring.yml
SOPS_AGE_SSH_PRIVATE_KEY_FILE=~/.ssh/id_ed25519 \
  ansible-playbook -i inventory.yml playbooks/06-next-terminal.yml
SOPS_AGE_SSH_PRIVATE_KEY_FILE=~/.ssh/id_ed25519 \
  ansible-playbook -i inventory.yml playbooks/08-ops-portal.yml
SOPS_AGE_SSH_PRIVATE_KEY_FILE=~/.ssh/id_ed25519 \
  ansible-playbook -i inventory.yml playbooks/09-configure-services.yml
```

## 部署后清理

部署成功后可以选择性清理旧的配置：

```bash
# 备份旧的 playbooks（可选）
cd ~/ansible/k3s/playbooks
mkdir old-ansible-managed
mv 05-monitoring.yml 06-next-terminal.yml 08-ops-portal.yml 09-configure-services.yml old-ansible-managed/

# 更新文档
vim README.md  # 添加新架构说明
```

## 成功标准

部署成功的标志：

✅ 所有 ArgoCD 应用显示 "Synced" 和 "Healthy"
✅ 访问任意服务自动跳转 Authelia 登录
✅ 登录一次后可以无缝访问所有服务
✅ Grafana 可以看到 Prometheus/Loki/Tempo 数据源
✅ Homarr 显示所有服务卡片且状态为在线（绿点）

## 下一步

部署成功后：

1. **更改默认密码**
   - ArgoCD admin 密码
   - LLDAP calvinhong 密码
   - Grafana admin 密码（如果使用）

2. **配置 Homarr 面板**
   - 添加更多服务卡片
   - 自定义主题和布局

3. **配置监控告警**
   - Grafana 告警规则
   - Alertmanager 通知渠道

4. **备份关键数据**
   - ArgoCD admin 密码
   - Authelia session encryption keys
   - 所有 PVC 数据

5. **部署业务应用**
   - 创建 `deploy/gitops/business/sub2api.yaml`
   - 添加到 ArgoCD
