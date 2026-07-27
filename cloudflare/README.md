# Cloudflare Tunnel — CRGS Admin

Exposes local CRGS services via Cloudflare Tunnel on `rfoodinternational.com`.

| Hostname | Local service |
|---|---|
| https://crgs.rfoodinternational.com | Frontend (Vite) `127.0.0.1:5317` |
| https://crgs-api.rfoodinternational.com | Backend (Flask) `127.0.0.1:5318` |

## Prerequisites

1. `cloudflared` installed and on PATH
2. Frontend running: `cd frontend && npm run dev` (port `5317`)
3. Backend running on port `5318`

## Start tunnel

```powershell
cd cloudflare
.\start-tunnel.ps1
```

Or:

```bat
cloudflare\start-tunnel.bat
```

## Files

- `config.yml` — tunnel ingress rules
- `382e5d55-e412-44e9-8e41-cee8f4ca79b4.json` — tunnel credentials (gitignored)
- `start-tunnel.ps1` / `start-tunnel.bat` — runners

## Tunnel details

- Name: `crgs-admin`
- ID: `382e5d55-e412-44e9-8e41-cee8f4ca79b4`
- CNAME target: `382e5d55-e412-44e9-8e41-cee8f4ca79b4.cfargotunnel.com`

## Notes

- Update backend `CORS_ORIGINS` to include `https://crgs.rfoodinternational.com` if you disable `CORS_ALLOW_ALL`.
- Point the Flutter/web app API base URL at `https://crgs-api.rfoodinternational.com` when using the public hostname.
- Origin cert for zone `rfoodinternational.com` is in `%USERPROFILE%\.cloudflared\cert.pem`.
- Previous zone cert backed up as `cert.pem.rawabihypermarket`.

## Security

- All `/api/*` routes require `Authorization: Bearer <JWT>` except `/api/auth/login`, `/api/health`, and product-review image files.
- Login is rate-limited (10/min per client IP / CF-Connecting-IP).
- Passwords are bcrypt-hashed (legacy plaintext upgraded on next successful login).
- CORS is restricted to `CORS_ORIGINS` (not `*`).
- Keep `backend/.env` out of git; rotate `SECRET_KEY` and Oracle password if they were ever committed.

## PM2

From project root:

```powershell
pm2 start ecosystem.config.cjs
pm2 save
```

| PM2 name | Role | Port |
|---|---|---|
| `crgs-web` | Frontend (Vite) | 5317 |
| `crgs-api` | Backend (Flask) | 5318 |
| `crgs-tunnel` | Cloudflare Tunnel | — |
