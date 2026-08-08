"""Tiny in-process TTL cache for semi-static GET responses."""

from __future__ import annotations

import hashlib
import json
import threading
import time
from typing import Any

_lock = threading.Lock()
_store: dict[str, tuple[float, Any]] = {}

# Hard cap so a burst of unique keys cannot grow without bound.
_MAX_ENTRIES = 512


def _evict_expired_unlocked(now: float) -> None:
    expired = [key for key, (expires_at, _) in _store.items() if expires_at < now]
    for key in expired:
        _store.pop(key, None)


def _evict_overflow_unlocked() -> None:
    """Drop soonest-to-expire entries when over capacity."""
    overflow = len(_store) - _MAX_ENTRIES
    if overflow <= 0:
        return
    by_expiry = sorted(_store.items(), key=lambda item: item[1][0])
    for key, _ in by_expiry[:overflow]:
        _store.pop(key, None)


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
    now = time.monotonic()
    with _lock:
        _evict_expired_unlocked(now)
        _store[key] = (now + ttl_seconds, value)
        _evict_overflow_unlocked()


def cache_delete_prefix(prefix: str) -> None:
    with _lock:
        doomed = [key for key in _store if key.startswith(prefix)]
        for key in doomed:
            _store.pop(key, None)


def etag_for_payload(payload: Any) -> str:
    raw = json.dumps(payload, sort_keys=True, default=str, separators=(",", ":"))
    digest = hashlib.sha1(raw.encode("utf-8")).hexdigest()
    return f'W/"{digest}"'
