@echo off
REM Start CRGS Cloudflare Tunnel (frontend + API)
cd /d "%~dp0"
cloudflared tunnel --config "%~dp0config.yml" run crgs-admin
