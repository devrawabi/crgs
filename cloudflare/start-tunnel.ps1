# Start CRGS Cloudflare Tunnel
# Requires: frontend on :5317, backend on :5318
Set-Location $PSScriptRoot
cloudflared tunnel --config "$PSScriptRoot\config.yml" run crgs-admin
