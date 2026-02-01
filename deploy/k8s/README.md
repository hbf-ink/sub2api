# K8s 部署说明

## 1. 创建命名空间
```bash
kubectl create namespace sub2api
```

## 2. 创建 GHCR 拉取密钥
```bash
# 在 GitHub 创建 Personal Access Token (PAT)，勾选 read:packages 权限
kubectl create secret docker-registry ghcr-secret \
  --namespace sub2api \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_GITHUB_PAT \
  --docker-email=YOUR_EMAIL
```

## 3. 创建配置密钥
```bash
kubectl create secret generic sub2api-config \
  --namespace sub2api \
  --from-file=config.yaml=./config.yaml
```

## 4. 部署 ArgoCD Application
```bash
kubectl apply -f argocd-app.yaml
```

## 发布流程

### 生产发布
```bash
git tag v0.2.0
git push origin v0.2.0
# 然后更新 kustomization.yaml 中的 newTag
```

### Beta 发布
```bash
git checkout beta
git merge main  # 或 cherry-pick
git push origin beta
# 自动构建 ghcr.io/hbf-ink/sub2api:beta
```
