# CRGS API security operations

## Required before production

1. **Rotate secrets** that may have appeared in git history:
   - `SECRET_KEY`
   - `ORACLE_PASSWORD`
   - any other credentials previously committed in `.env`
2. **Scrub git history** (or treat the repo as compromised and rotate everything):
   - Use `git filter-repo` / BFG to remove `.env` blobs, then force-push only with ops approval.
3. Set portal role envs (keep in sync with `frontend/src/lib/roleAccess.ts`):
   - **`ADMIN_ROLE_CODES`** (default `1,3,4,6,8`) — full portal (Dashboard + User Management)
   - **`MANAGER_ROLE_CODES`** (default `2,5`) — portal minus Dashboard + User Management
   - **`CALL_CENTER_ROLE_CODES`** (default `9`) — Call Center screen (FE); may list users for that UI
   - Call Center **nav** is shown only to roles **1** and **9** (frontend)
   - Only actor **role code 1** may create users with designations **1** or **9**
   - Production boot **fails** if admin roles are empty (`REQUIRE_ADMIN_ROLES=true`)
4. Use a **`SECRET_KEY` ≥ 32 characters** (boot enforces `SECRET_KEY_MIN_LENGTH`).
5. Keep **`CORS_ALLOW_ALL=false`** outside development (boot rejects otherwise).
6. Behind Cloudflare, keep **`TRUST_PROXY=true`** so rate limits use `CF-Connecting-IP` only (not spoofable `X-Forwarded-For`).

## AuthZ model

| Actor | Behavior |
|-------|----------|
| Unauthenticated | Only `/api/health` and `/api/auth/login` |
| Non-portal JWT | Forced to own `employeeCode` on scoped APIs |
| Manager (`MANAGER_ROLE_CODES`) | Management APIs / all-employee scope; list users; assign routes; **not** user create/status or dashboard summary |
| Full admin (`ADMIN_ROLE_CODES`) | Manager scope + dashboard summary + user create/status |
| Call center (`CALL_CENTER_ROLE_CODES`) | Authenticated APIs; list users; FE shows Call Center only |
| JSON `isAdmin` | **Full admin only** (not managers) |
| JSON `isManager` / `isCallCenter` | Matching role sets |
| `canManage` / Python `is_admin()` | Full admin **or** manager |

## Passwords

- New passwords: min length from `PASSWORD_MIN_LENGTH` (default 8), stored as bcrypt.
- Legacy plaintext verify is **off** unless `ALLOW_LEGACY_PLAINTEXT_PASSWORDS=true` (migrate ASAP).

## JWT

- Default expiry **4 hours** (`JWT_EXPIRE_HOURS`).
- No server-side revoke list; shorten TTL + rotate `SECRET_KEY` to invalidate all tokens.

## Clients

- Admin UI: sessionStorage JWT + role-gated nav (`roleAccess.ts`) + `AdminRoute` / `RoleRoute`.
- Flutter: JWT in `flutter_secure_storage` (not SharedPreferences).
