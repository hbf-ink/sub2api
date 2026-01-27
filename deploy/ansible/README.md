# Sub2API Ansible 部署

## 快速开始

### 1. 安装 Ansible（在主控节点）

```bash
# Ubuntu/Debian
apt-get install -y ansible

# macOS
brew install ansible
```

### 2. 配置 SSH

确保主控节点能免密登录所有工作节点：

```bash
ssh-copy-id root@149.104.8.233 -p 46182
ssh-copy-id ubuntu@43.163.210.42
```

### 3. 测试连接

```bash
cd deploy/ansible
ansible -i inventory.yml all -m ping
```

## 常用命令

### 检查所有节点状态

```bash
ansible-playbook -i inventory.yml check-status.yml
```

### 滚动更新所有节点

```bash
# 更新到 latest
ansible-playbook -i inventory.yml rolling-update.yml

# 更新到指定版本
ansible-playbook -i inventory.yml rolling-update.yml -e "sub2api_tag=v1.2.3"
```

### 只更新特定节点

```bash
ansible-playbook -i inventory.yml rolling-update.yml -e "target_hosts=calvin-hk-loc"
```

### Dry-run（不实际执行）

```bash
ansible-playbook -i inventory.yml rolling-update.yml --check
```

## 节点清单

| 节点名 | IP | 端口 | 区域 | 供应商 | Beta |
|--------|-----|------|------|--------|------|
| calvin-hk-loc | 149.104.8.233 | 46182 | hk | locvps | ❌ |
| calvin-jp-zeabur | 43.163.210.42 | 22 | jp | zeabur | ✅ |

## 添加新节点

1. 在新机器上运行初始化脚本：

```bash
curl -fsSL https://raw.githubusercontent.com/hbf-ink/sub2api/main/deploy/scripts/init-node.sh | bash -s -- \
  --region=sg \
  --provider=vultr \
  --db-url="postgres://user:pass@host:5432/db?sslmode=require"
```

2. 在 `inventory.yml` 中添加节点：

```yaml
calvin-sg-vultr:
  ansible_host: x.x.x.x
  ansible_port: 22
  node_region: sg
  node_provider: vultr
  node_beta: false
```

3. 测试连接：

```bash
ansible -i inventory.yml calvin-sg-vultr -m ping
```

## 目录结构

```
deploy/ansible/
├── inventory.yml       # 节点清单
├── rolling-update.yml  # 滚动更新 playbook
├── check-status.yml    # 状态检查 playbook
└── README.md           # 本文档
```
