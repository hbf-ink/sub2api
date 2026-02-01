# K3s 集群一键恢复指南

## 前置条件

1. **新服务器**: Ubuntu 24.04，已配置 SSH 访问
2. **本地环境**: 
   - SSH 私钥 `~/.ssh/id_ed25519`（用于 SOPS 解密和 SSH 连接）
   - 安装 `sshpass`（WSL 下）

## 恢复步骤

### 1. 更新 inventory.yml

修改 `deploy/ansible/k3s/inventory.yml` 中的 IP 地址：

```yaml
all:
  children:
    ops:
      hosts:
        ops-tokyo-01:
          ansible_host: <新运维机IP>
          ...
    prod:
      hosts:
        prod-tokyo-01:
          ansible_host: <新业务机IP>
          ...
```

### 2. 上传文件到运维机

```bash
# 清除旧的 SSH host key
ssh-keygen -R <新运维机IP>
ssh-keygen -R <新业务机IP>

# 上传 SSH 私钥（用于 SOPS 解密和连接业务机）
scp ~/.ssh/id_ed25519 ubuntu@<运维机IP>:~/.ssh/
ssh ubuntu@<运维机IP> 'chmod 600 ~/.ssh/id_ed25519'

# 上传 Ansible 文件
scp -r deploy/ansible/k3s/* ubuntu@<运维机IP>:~/ansible/k3s/
```

### 3. 安装依赖（运维机）

```bash
ssh ubuntu@<运维机IP>

# 安装 Ansible 和 SOPS
sudo apt update && sudo apt install -y ansible sshpass
curl -LO https://github.com/getsops/sops/releases/download/v3.9.4/sops-v3.9.4.linux.amd64
chmod +x sops-v3.9.4.linux.amd64 && sudo mv sops-v3.9.4.linux.amd64 /usr/local/bin/sops

# 安装 Ansible SOPS 插件
ansible-galaxy collection install community.sops
```

### 4. 一键部署

```bash
cd ~/ansible/k3s

# 运行全部 playbook
ansible-playbook -i inventory.yml site.yml
```

或分步执行：

```bash
# 1. 基础环境
ansible-playbook -i inventory.yml playbooks/01-base.yml

# 2. WireGuard 组网
ansible-playbook -i inventory.yml playbooks/02-wireguard.yml

# 3. K3s Server
ansible-playbook -i inventory.yml playbooks/03-k3s-server.yml

# 4. K3s Agent
ansible-playbook -i inventory.yml playbooks/04-k3s-agent.yml

# 5. 监控栈
ansible-playbook -i inventory.yml playbooks/05-monitoring.yml

# 6. 堡垒机
ansible-playbook -i inventory.yml playbooks/06-next-terminal.yml

# 7. SSH 安全
ansible-playbook -i inventory.yml playbooks/07-ssh-security.yml

# 8. 运维门户 (Homarr + LLDAP)
ansible-playbook -i inventory.yml playbooks/08-ops-portal.yml
```

### 5. 从 R2 恢复数据（可选）

如果需要恢复之前的数据：

```bash
ansible-playbook -i inventory.yml playbooks/09-restore.yml
```

## 访问信息

部署完成后：

| 服务 | 地址 |
|------|------|
| 运维首页 | https://ops.hbf.ink |
| LLDAP 用户管理 | https://ops.hbf.ink/lldap |
| Grafana 监控 | https://ops.hbf.ink/grafana |
| Next Terminal | https://ops.hbf.ink/terminal |

## 密钥管理

### 解密 secrets.enc.yml

```bash
# 需要 SSH 私钥 ~/.ssh/id_ed25519
sops -d secrets.enc.yml
```

### 修改密钥后重新加密

```bash
sops secrets.enc.yml  # 直接编辑
# 或
sops -d secrets.enc.yml > secrets.yml
# 编辑 secrets.yml
sops -e secrets.yml > secrets.enc.yml
rm secrets.yml
```

## 故障排除

### SOPS 解密失败

确保 SSH 私钥存在且权限正确：
```bash
ls -la ~/.ssh/id_ed25519  # 应为 -rw-------
```

### Ansible 连接失败

检查 inventory 中的 IP 和用户是否正确，SSH 密钥是否已添加到目标服务器。

### WireGuard 连接不通

检查防火墙是否开放 51820/udp 端口。
