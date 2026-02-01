# SSH 隧道到 test.hbf.ink
# 本地 3001 端口 -> VPS 9001 端口 -> Caddy -> test.hbf.ink
Write-Host "Starting SSH tunnel: localhost:3001 -> test.hbf.ink"
Write-Host "Press Ctrl+C to stop"
ssh -R 9001:localhost:3001 -N -o ServerAliveInterval=30 -o ServerAliveCountMax=3 root@us2.hbf.ink
