from __future__ import annotations

from functools import wraps
from typing import Callable, Iterable

from flask import current_app, g, jsonify, request

from app.security.tokens import decode_access_token

# Unauthenticated endpoints only. Review images require auth (signed by JWT).
PUBLIC_Exact = {
    "/api/health",
    "/api/auth/login",
}

PUBLIC_PREFIXES: tuple[str, ...] = ()


def _extract_bearer() -> str | None:
    header = request.headers.get("Authorization", "")
    if not header.startswith("Bearer "):
        return None
    token = header[7:].strip()
    return token or None


def is_public_request() -> bool:
    if request.method == "OPTIONS":
        return True
    path = request.path.rstrip("/") or "/"
    if path in PUBLIC_Exact:
        return True
    return any(request.path.startswith(prefix) for prefix in PUBLIC_PREFIXES)


def load_current_user_from_token() -> tuple[dict | None, tuple | None]:
    """Returns (user, error_response). error_response is (json, status)."""
    token = _extract_bearer()
    if not token:
        return None, (jsonify({"error": "Authentication required"}), 401)
    try:
        payload = decode_access_token(token)
    except Exception:
        return None, (jsonify({"error": "Invalid or expired token"}), 401)

    user = {
        "employeeCode": str(payload.get("sub", "")).strip(),
        "username": str(payload.get("username", "")).strip(),
        "roleCode": normalize_role_code(payload.get("roleCode")),
        "route": payload.get("route"),
    }
    if not user["employeeCode"]:
        return None, (jsonify({"error": "Invalid token subject"}), 401)
    return user, None


def current_user() -> dict:
    return getattr(g, "current_user", None) or {}


def current_employee_code() -> str:
    return str(current_user().get("employeeCode", "")).strip()


def normalize_role_code(value) -> str:
    """Normalize ROLECODE from Oracle/JWT (handles 1, '1', 1.0, Decimal)."""
    if value is None:
        return ""
    text = str(value).strip()
    if not text:
        return ""
    # Oracle NUMBER often arrives as float/Decimal → "1.0"
    try:
        num = float(text)
        if num.is_integer():
            return str(int(num))
    except (TypeError, ValueError):
        pass
    return text


def admin_role_codes() -> set[str]:
    """Full admins (Dashboard + User Management + all APIs)."""
    return parse_admin_roles(current_app.config.get("ADMIN_ROLE_CODES"))


def manager_role_codes() -> set[str]:
    """Managers: portal minus Dashboard / User Management."""
    return parse_admin_roles(current_app.config.get("MANAGER_ROLE_CODES"))


def call_center_role_codes() -> set[str]:
    """Call Center tab only."""
    return parse_admin_roles(current_app.config.get("CALL_CENTER_ROLE_CODES"))


def is_full_admin(user: dict | None = None) -> bool:
    roles = admin_role_codes()
    if not roles:
        return False
    role = normalize_role_code((user or current_user()).get("roleCode"))
    return role in roles


def is_manager(user: dict | None = None) -> bool:
    roles = manager_role_codes()
    if not roles:
        return False
    role = normalize_role_code((user or current_user()).get("roleCode"))
    return role in roles


def is_call_center(user: dict | None = None) -> bool:
    roles = call_center_role_codes()
    if not roles:
        return False
    role = normalize_role_code((user or current_user()).get("roleCode"))
    return role in roles


def is_admin(user: dict | None = None) -> bool:
    """Full admin or manager — management APIs / all-employee scope."""
    return is_full_admin(user) or is_manager(user)


def can_list_users(user: dict | None = None) -> bool:
    """Admins, managers, and call-center agents may list users."""
    return is_admin(user) or is_call_center(user)


# Creating users with these ROLECODEs requires actor ROLECODE 1.
RESTRICTED_CREATE_ROLE_CODES = frozenset({"1", "9"})
SUPER_USER_CREATOR_ROLE = "1"


def can_create_role_code(target_role_code, actor: dict | None = None) -> bool:
    target = normalize_role_code(target_role_code)
    if target not in RESTRICTED_CREATE_ROLE_CODES:
        return True
    actor_role = normalize_role_code((actor or current_user()).get("roleCode"))
    return actor_role == SUPER_USER_CREATOR_ROLE


def require_auth(view: Callable):
    @wraps(view)
    def wrapped(*args, **kwargs):
        user, err = load_current_user_from_token()
        if err is not None:
            return err
        g.current_user = user
        return view(*args, **kwargs)

    return wrapped


def require_roles(*allowed: str):
    allowed_set = {normalize_role_code(a) for a in allowed if normalize_role_code(a)}

    def decorator(view: Callable):
        @wraps(view)
        @require_auth
        def wrapped(*args, **kwargs):
            role = normalize_role_code(getattr(g, "current_user", {}).get("roleCode"))
            if allowed_set and role not in allowed_set:
                return jsonify({"error": "Forbidden"}), 403
            return view(*args, **kwargs)

        return wrapped

    return decorator


def require_admin(view: Callable):
    """Require full admin or manager role (management APIs)."""

    @wraps(view)
    def wrapped(*args, **kwargs):
        if not admin_role_codes() and not manager_role_codes():
            return jsonify({"error": "Admin roles are not configured"}), 503
        if not is_admin():
            return jsonify({"error": "Forbidden"}), 403
        return view(*args, **kwargs)

    return wrapped


def require_full_admin(view: Callable):
    """Require full admin only (Dashboard + User Management)."""

    @wraps(view)
    def wrapped(*args, **kwargs):
        if not admin_role_codes():
            return jsonify({"error": "Admin roles are not configured"}), 503
        if not is_full_admin():
            return jsonify({"error": "Forbidden"}), 403
        return view(*args, **kwargs)

    return wrapped


def require_user_list(view: Callable):
    """Admins, managers, and call-center roles may list users."""

    @wraps(view)
    def wrapped(*args, **kwargs):
        if not can_list_users():
            return jsonify({"error": "Forbidden"}), 403
        return view(*args, **kwargs)

    return wrapped


def parse_admin_roles(raw: str | Iterable[str] | None) -> set[str]:
    if raw is None:
        return set()
    if isinstance(raw, str):
        parts = raw.split(",")
    else:
        parts = list(raw)
    return {normalize_role_code(p) for p in parts if normalize_role_code(p)}


def resolve_employee_scope(
    requested: str | None = None,
    *,
    allow_all_for_admin: bool = True,
) -> tuple[str | None, tuple | None]:
    """
    Resolve which employeeCode filter to apply.

    - Non-admin: always own code. Mismatch with requested → 403.
    - Admin: requested code, or None (= all) when allow_all_for_admin.
    """
    me = current_employee_code()
    if not me:
        return None, (jsonify({"error": "Authentication required"}), 401)

    req = str(requested or "").strip()
    if is_admin():
        if req:
            return req, None
        return (None if allow_all_for_admin else me), None

    if req and req.upper() != me.upper():
        return None, (jsonify({"error": "Forbidden"}), 403)
    return me, None


def enforce_owned_employee_code(requested: str | None) -> tuple[str | None, tuple | None]:
    """
    For create/update bodies: non-admin must act as self; admin may set any code.
    Returns (employee_code, error).
    """
    me = current_employee_code()
    if not me:
        return None, (jsonify({"error": "Authentication required"}), 401)

    req = str(requested or "").strip()
    if is_admin():
        code = req or me
        if not code:
            return None, (jsonify({"error": "Employee code is required"}), 400)
        return code, None

    if req and req.upper() != me.upper():
        return None, (jsonify({"error": "Forbidden"}), 403)
    return me, None


def trusted_client_ip() -> str:
    """
    Rate-limit / audit IP.

    When TRUST_PROXY=true (Cloudflare), prefer CF-Connecting-IP only.
    Otherwise use remote_addr — ignore spoofable X-Forwarded-For.
    """
    trust_proxy = str(current_app.config.get("TRUST_PROXY", "")).lower() in (
        "1",
        "true",
        "yes",
    )
    if trust_proxy:
        cf_ip = (request.headers.get("CF-Connecting-IP") or "").strip()
        if cf_ip:
            return cf_ip
    return request.remote_addr or "unknown"
