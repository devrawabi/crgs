from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

import jwt
from flask import current_app


def create_access_token(
    *,
    employee_code: str,
    username: str,
    role_code: str | int | None,
    route: str | None = None,
) -> str:
    now = datetime.now(timezone.utc)
    hours = int(current_app.config.get("JWT_EXPIRE_HOURS", 12))
    payload: dict[str, Any] = {
        "sub": str(employee_code).strip(),
        "username": str(username).strip(),
        "roleCode": "" if role_code is None else str(role_code).strip(),
        "route": (route or "").strip() or None,
        "iat": now,
        "exp": now + timedelta(hours=hours),
        "iss": current_app.config.get("JWT_ISSUER", "crgs-admin"),
    }
    return jwt.encode(
        payload,
        current_app.config["SECRET_KEY"],
        algorithm=current_app.config.get("JWT_ALGORITHM", "HS256"),
    )


def decode_access_token(token: str) -> dict[str, Any]:
    return jwt.decode(
        token,
        current_app.config["SECRET_KEY"],
        algorithms=[current_app.config.get("JWT_ALGORITHM", "HS256")],
        issuer=current_app.config.get("JWT_ISSUER", "crgs-admin"),
    )
