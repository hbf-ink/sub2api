# Wetty - Web SSH Terminal
FROM wettyoss/wetty:latest

# 设置环境变量
ENV WETTY_PORT=3000
ENV WETTY_BASE=/terminal
ENV WETTY_TITLE="HBF Operations Terminal"

# 暴露端口
EXPOSE 3000

# 启动命令会通过环境变量配置
CMD ["node", "/usr/src/app/dist/server.js"]
