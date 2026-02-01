# Sub2API K3s 集群部署

使用 Ansible 自动化部署 K3s 集群、监控栈、堡垒机。

## 架构

```
┌─────────────────────────────────────────────────────────────┐
│                     Tailscale 组网                          │
│  ┌─────────────────────┐      ┌─────────────────────┐      │
│  │   ops-tokyo-01      │      │   prod-tokyo-01     │      │
│  │   (运维机/堡垒机)    │◄────►│   (业务机)          │      │
│  │   腾讯云 2C/4GB     │      │   阿里云 2C/4GB     │      │
│  │                     │      │                     │      │
│  │   - K3s Server      │      │   - K3s Agent       │      │
│  │   - Prometheus      │      │   - Sub2API         │      │
│  │   - Loki            │      │   - PostgreSQL      │      │
│  │   - Grafana         │      │   - Redis           │      │
│  │   - Tempo           │      │                     │      │
│  │   - Next Terminal   │      │                     │      │
│  └─────────────────────┘      └─────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## 前置条件

1. 两台 Ubuntu 24.04 服务器
2. Tailscale 账号和 Auth Key
3. 本地安装 Ansible 或从运维机执行

## 快速开始

### 1. 获取 Tailscale Auth Key

访问 https://login.tailscale.com/admin/settings/keys 创建 Auth Key（建议 Reusable + Ephemeral）

### 2. 配置 inventory

编辑 `inventory.yml`，填入服务器 IP 和密码

### 3. 设置环境变量

```bash
export TAILSCALE_AUTHKEY="tskey-auth-xxxxx"
```

### 4. 执行部署

```bash
cd deploy/ansible/k3s

# 完整部署
ansible-playbook -i inventory.yml site.yml

# 或分步执行
ansible-playbook -i inventory.yml playbooks/01-base.yml
ansible-playbook -i inventory.yml playbooks/02-tailscale.yml
ansible-playbook -i inventory.yml playbooks/03-k3s-server.yml
ansible-playbook -i inventory.yml playbooks/04-k3s-agent.yml
ansible-playbook -i inventory.yml playbooks/05-monitoring.yml
ansible-playbook -i inventory.yml playbooks/06-next-terminal.yml
ansible-playbook -i inventory.yml playbooks/07-ssh-security.yml
```

## 部署完成后

| 服务 | 地址 | 默认账号 |
|------|------|----------|
| Grafana | http://ops-tailscale-ip:30030 | admin / admin123 |
| Next Terminal | http://ops-tailscale-ip:30088 | 首次访问设置 |

## 文件结构

```
k3s/
├── ansible.cfg           # Ansible 配置
├── site.yml              # 主入口
├── inventory.yml         # 主机清单
├── group_vars/
│   └── all.yml           # 全局变量
└── playbooks/
    ├── 01-base.yml       # 基础环境
    ├── 02-tailscale.yml  # Tailscale 组网
    ├── 03-k3s-server.yml # K3s Server
    ├── 04-k3s-agent.yml  # K3s Agent
    ├── 05-monitoring.yml # 监控栈
    ├── 06-next-terminal.yml # 堡垒机
    └── 07-ssh-security.yml  # SSH 加固
```

## 灾难恢复

如需重建集群，先在所有节点执行卸载：

```bash
# 在 Server 节点
/usr/local/bin/k3s-uninstall.sh

# 在 Agent 节点
/usr/local/bin/k3s-agent-uninstall.sh
```

然后重新执行 `ansible-playbook -i inventory.yml site.yml`
