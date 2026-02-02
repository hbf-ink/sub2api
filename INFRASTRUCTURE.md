# 基础设施部署

> **注意：** 基础设施配置已迁移到独立仓库

## 📦 基础设施仓库

所有通用基础设施（K3s、监控、认证、运维工具）现在统一管理在：

🔗 **https://github.com/hbf-ink/infra**

包括：
- VPS Ansible 部署（K3s + WireGuard + 监控）
- GitOps 配置（ArgoCD 应用定义）
- Zeabur 服务（Wetty、OpenClaw 等）
- 通用运维工具和脚本

## 🚀 Sub2API 专属部署

本仓库只保留 Sub2API 业务相关的部署配置：

```
deploy/
├── k8s/              # Sub2API K8s 部署清单
├── scripts/          # Sub2API 专用脚本
├── docker-compose.yml   # Docker Compose 部署
└── install.sh        # 快速安装脚本
```

## 📝 部署指南

### 1. 部署基础设施

```bash
# Clone 基础设施仓库
git clone git@github.com:hbf-ink/infra.git
cd infra/vps/ansible

# 部署完整基础设施
ansible-playbook -i inventory.yml site.yml
```

### 2. 部署 Sub2API

基础设施就绪后，部署 Sub2API：

```bash
# 返回 sub2api 仓库
cd /path/to/sub2api

# 使用 K8s 部署
kubectl apply -f deploy/k8s/

# 或使用 Docker Compose
docker-compose -f deploy/docker-compose.yml up -d
```

## 🔗 相关文档

- [基础设施架构](https://github.com/hbf-ink/infra/blob/main/docs/architecture.md)
- [Ansible 快速指南](https://github.com/hbf-ink/infra/blob/main/vps/ansible/QUICKSTART.md)
- [Sub2API 部署文档](./deploy/README.md)
