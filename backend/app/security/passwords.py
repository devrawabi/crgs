from __future__ import annotations

import bcrypt
from flask import current_app


def hash_password(plain: str) -> str:
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt(rounds=12)).decode(
        "utf-8"
    )


def is_password_hash(value: str | None) -> bool:
    if not value:
        return False
    return value.startswith(("$2a$", "$2b$", "$2y$"))


def verify_password(plain: str, stored: str | None) -> bool:
    if not stored:
        return False
    if is_password_hash(stored):
        try:
            return bcrypt.checkpw(plain.encode("utf-8"), stored.encode("utf-8"))
        except (ValueError, TypeError):
            return False
    # Legacy plaintext — disabled unless explicitly enabled.
    allow_legacy = str(
        current_app.config.get("ALLOW_LEGACY_PLAINTEXT_PASSWORDS", "false")
    ).lower() in ("1", "true", "yes")
    if not allow_legacy:
        return False
    # Constant-time compare for equal-length strings.
    if len(plain) != len(stored):
        return False
    result = 0
    for left, right in zip(plain.encode("utf-8"), stored.encode("utf-8")):
        result |= left ^ right
    return result == 0


def validate_password_strength(plain: str) -> str | None:
    """Return error message or None if acceptable."""
    min_len = int(current_app.config.get("PASSWORD_MIN_LENGTH", 8))
    if len(plain) < min_len:
        return f"Password must be at least {min_len} characters"
    if plain.strip() != plain:
        return "Password cannot start or end with whitespace"
    return None
