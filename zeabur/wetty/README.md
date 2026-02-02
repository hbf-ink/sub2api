# Wetty 部署到 Zeabur

## 简介

Wetty 是一个轻量级的 Web SSH 客户端，可以在浏览器中直接 SSH 到服务器。

## Zeabur 部署步骤

### 方式一：使用 Zeabur 控制台（推荐）

1. **登录 Zeabur**
   - 访问 https://dash.zeabur.com
   - 登录你的账号

2. **创建新项目**
   - 点击 "New Project"
   - 命名：`hbf-ops-tools`
   - 选择 Region: `ap-east` (香港，离东京最近)

3. **添加服务**
   - 点击 "Add Service"
   - 选择 "Docker Image"
   - 镜像名：`wettyoss/wetty:latest`

4. **配置环境变量**
   点击服务 → Environment Variables，添加：
   ```
   WETTY_PORT=3000
   WETTY_BASE=/
   WETTY_TITLE=HBF Operations Terminal
   WETTY_SSH_HOST=43.163.210.42
   WETTY_SSH_PORT=22
   WETTY_SSH_USER=ubuntu
   ```

5. **配置域名**
   - 点击 "Networking"
   - 添加域名：`terminal.hbf.ink`
   - 或使用 Zeabur 提供的免费域名：`xxx.zeabur.app`

6. **部署**
   - 点击 "Deploy"
   - 等待部署完成（约 1-2 分钟）

### 方式二：使用 GitHub 部署

1. **推送代码到 GitHub**
   ```bash
   cd C:\Users\calvin\hbf-sub2api
   git add zeabur/
   git commit -m "feat: 添加 Wetty Zeabur 配置"
   git push
   ```

2. **在 Zeabur 连接 GitHub**
   - 在 Zeabur 项目中点击 "Add Service"
   - 选择 "Git Repository"
   - 选择 `hbf-ink/sub2api` 仓库
   - 选择 `zeabur/wetty` 目录

3. **Zeabur 会自动检测 Dockerfile 并部署**

## 使用方法

部署完成后：

1. **访问 Web 终端**
   ```
   https://terminal.hbf.ink
   或
   https://your-service.zeabur.app
   ```

2. **登录服务器**
   - 输入密码：`y#AV(ZjOHNp0}9u>G7`
   - 或使用 SSH Key（需要上传公钥到服务器）

3. **使用场景**
   - 应急运维（在外面没有 SSH 客户端）
   - 移动端访问（手机浏览器）
   - 团队协作（分享链接给临时访客）

## 配置说明

| 环境变量 | 说明 | 默认值 |
|---------|------|--------|
| `WETTY_PORT` | 服务端口 | 3000 |
| `WETTY_BASE` | URL 基础路径 | / |
| `WETTY_TITLE` | 页面标题 | Wetty |
| `WETTY_SSH_HOST` | SSH 服务器地址 | 必填 |
| `WETTY_SSH_PORT` | SSH 端口 | 22 |
| `WETTY_SSH_USER` | 默认用户名 | 可选 |

## 安全建议

1. **配置 Authelia 认证**
   - 在 Traefik 配置中添加 ForwardAuth
   - 访问 Wetty 前先通过 Authelia 登录

2. **配置 IP 白名单**（可选）
   - 在 Zeabur 或 Cloudflare 配置 IP 限制
   - 只允许信任的 IP 访问

3. **使用 SSH Key 而不是密码**
   - 在 VPS 上配置公钥认证
   - 禁用密码登录

## 成本预估

- **内存占用**: ~30-50MB
- **CPU**: 几乎为 0（空闲时）
- **Zeabur 费用**: ~$0.3-0.5/月（在 $5 免费额度内）

## 故障排查

### 无法连接到 SSH 服务器

检查环境变量：
```bash
# 确认 VPS 防火墙允许 Zeabur IP
sudo ufw status
sudo ufw allow from any to any port 22
```

### 页面无法访问

1. 检查 Zeabur 服务状态
2. 检查域名 DNS 解析
3. 查看 Zeabur 服务日志

### 连接很慢

1. 确认 Region 选择（香港最近）
2. 考虑使用 WireGuard VPN 内网连接

## 升级到 JumpServer

如果需要更强大的功能（录像、审计、多协议），可以升级到 JumpServer：

```bash
# JumpServer 也可以部署在 Zeabur
# 需要多个服务：Core + Koko + Lion + Web
# 预计费用：$2-3/月（仍在免费额度内）
```
