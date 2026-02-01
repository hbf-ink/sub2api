# Sub2API K3s 集群恢复指南

## 快速恢复

### 方式一：在 ops 机器上直接恢复（推荐）

```bash
# 1. SSH 到新的 ops 机器
ssh ubuntu@<ops_ip>

# 2. 恢复 SSH 私钥（用于 SOPS 解密）
# 从 R2 备份下载，或从其他安全位置获取
mkdir -p ~/.ssh
# 方法A: 从 R2
rclone copy r2:hbf-backup/keys/id_ed25519 ~/.ssh/
# 方法B: 从本地上传
# scp ~/.ssh/id_ed25519 ubuntu@<ops_ip>:~/.ssh/
chmod 600 ~/.ssh/id_ed25519

# 3. 克隆仓库并恢复
git clone git@github.com:hbf-ink/sub2api.git
cd sub2api/deploy/ansible/k3s
chmod +x local-recover.sh
./local-recover.sh              # 只恢复 ops
./local-recover.sh <prod_ip>    # 恢复 ops + prod
```

### 方式二：从任意机器远程恢复

```bash
# 1. 克隆仓库
git clone git@github.com:hbf-ink/sub2api.git
cd sub2api/deploy/ansible/k3s

# 2. 确保本机有 SSH 私钥 ~/.ssh/id_ed25519

# 3. 执行恢复
chmod +x recover.sh
./recover.sh <ops_ip> <password>                           # 只恢复 ops
./recover.sh <ops_ip> <password> <prod_ip> <prod_password> # 恢复 ops + prod
```

## SSH 私钥备份

**重要**: SSH 私钥 `~/.ssh/id_ed25519` 是解密 secrets 的唯一密钥，必须安全备份！

```bash
# 备份到 R2
rclone copy ~/.ssh/id_ed25519 r2:hbf-backup/keys/

# 或者保存到安全的密码管理器
```

## 场景说明

### 场景1: Ops 机器故障

完整重建控制面：
```bash
./local-recover.sh <prod_ip>  # 如果 prod 还在
./local-recover.sh            # 如果只恢复 ops
```

### 场景2: Prod 机器故障

Ops 还在，只需重新加入 prod：
```bash
cd ~/sub2api/deploy/ansible/k3s

# 更新 inventory.yml 中的 prod IP
vim inventory.yml

# 只运行 prod 相关 playbook
ansible-playbook -i inventory.yml playbooks/01-base.yml --limit prod
ansible-playbook -i inventory.yml playbooks/02-wireguard.yml
ansible-playbook -i inventory.yml playbooks/04-k3s-agent.yml
```

### 场景3: 新增 Prod 机器

```bash
# 编辑 inventory.yml 添加新节点
vim inventory.yml

# 部署新节点
ansible-playbook -i inventory.yml playbooks/01-base.yml --limit <new_node>
ansible-playbook -i inventory.yml playbooks/02-wireguard.yml
ansible-playbook -i inventory.yml playbooks/04-k3s-agent.yml --limit <new_node>
```

## 恢复后验证

```bash
# 检查节点状态
kubectl get nodes

# 检查所有 Pod
kubectl get pods -A

# 检查服务
curl -k https://ops.hbf.ink
```

## 访问信息

| 服务 | 地址 | 认证 |
|------|------|------|
| 运维首页 | https://ops.hbf.ink | - |
| Grafana | https://ops.hbf.ink/grafana | LDAP |
| Next Terminal | https://ops.hbf.ink/terminal | LDAP |
| LLDAP | https://ops.hbf.ink/lldap | 本地 |

**LDAP 账号**: `calvinhong` (密码在 LLDAP 中管理，改一次全部生效)

## 故障排除

### SOPS 解密失败
```bash
# 确认私钥存在且权限正确
ls -la ~/.ssh/id_ed25519  # 应该是 -rw-------
```

### K3s 节点不加入
```bash
# 检查 WireGuard 连通性
ping 10.10.0.1  # ops
ping 10.10.0.2  # prod

# 检查 K3s token
cat /var/lib/rancher/k3s/server/node-token
```

### 证书问题
```bash
# 重新签发证书
kubectl delete secret ops-tls -n ops
kubectl delete secret grafana-tls -n monitoring
# 等待 cert-manager 自动重新签发
```
