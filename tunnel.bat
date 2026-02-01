@echo off
echo Starting SSH tunnel to test.hbf.ink...
echo Local port 3001 -> test.hbf.ink
echo Press Ctrl+C to stop
ssh -R 9001:localhost:3001 -N root@us2.hbf.ink
