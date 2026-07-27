from __future__ import annotations

from functools import wraps
from typing import Callable, Iterable

from flask import g, jsonify, request

from app.security.tokens import decode_access_token

PUBLIC_Exact = {
    "/api/health",
    "/api/auth/login",
}

PUBLIC_PREFIXES = (
    "/api/product-reviews/images/",
)


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
    # Normalize trailing slash variants for exact allowlist
    candidates = {request.path, path, path + "/"}
    if candidates & PUBLIC_Exact or request.path in PUBLIC_Exact:
        return True
    # login without trailing slash already covered
    if request.path.rstrip("/") == "/api/auth/login":
        return True
    if request.path.rstrip("/") == "/api/health":
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
        "roleCode": str(payload.get("roleCode", "")).strip(),
        "route": payload.get("route"),
    }
    if not user["employeeCode"]:
        return None, (jsonify({"error": "Invalid token subject"}), 401)
    return user, None


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
    allowed_set = {str(a).strip() for a in allowed if str(a).strip()}

    def decorator(view: Callable):
        @wraps(view)
        @require_auth
        def wrapped(*args, **kwargs):
            role = str(getattr(g, "current_user", {}).get("roleCode", "")).strip()
            if allowed_set and role not in allowed_set:
                return jsonify({"error": "Forbidden"}), 403
            return view(*args, **kwargs)

        return wrapped

    return decorator


def parse_admin_roles(raw: str | Iterable[str] | None) -> set[str]:
    if raw is None:
        return set()
    if isinstance(raw, str):
        parts = raw.split(",")
    else:
        parts = list(raw)
    return {str(p).strip() for p in parts if str(p).strip()}
