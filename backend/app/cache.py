"""Tiny in-process TTL cache for semi-static GET responses."""

from __future__ import annotations

import hashlib
import json
import threading
import time
from typing import Any

_lock = threading.Lock()
_store: dict[str, tuple[float, Any]] = {}


def cache_get(key: str) -> Any | None:
    now = time.monotonic()
    with _lock:
        entry = _store.get(key)
        if entry is None:
            return None
        expires_at, value = entry
        if expires_at < now:
            _store.pop(key, None)
            return None
        return value


def cache_set(key: str, value: Any, *, ttl_seconds: float) -> None:
    if ttl_seconds <= 0:
        return
    with _lock:
        _store[key] = (time.monotonic() + ttl_seconds, value)


def cache_delete_prefix(prefix: str) -> None:
    with _lock:
        doomed = [key for key in _store if key.startswith(prefix)]
        for key in doomed:
            _store.pop(key, None)


def etag_for_payload(payload: Any) -> str:
    raw = json.dumps(payload, sort_keys=True, default=str, separators=(",", ":"))
    digest = hashlib.sha1(raw.encode("utf-8")).hexdigest()
    return f'W/"{digest}"'
