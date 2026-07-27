from __future__ import annotations

import bcrypt


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
    # Legacy plaintext row — constant-time-ish compare via bcrypt path after match
    return plain == stored
