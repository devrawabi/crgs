"""Thin Groq Chat Completions client (OpenAI-compatible HTTP API)."""

from __future__ import annotations

import json
import logging
import urllib.error
import urllib.request
from typing import Any

logger = logging.getLogger(__name__)

GROQ_CHAT_URL = "https://api.groq.com/openai/v1/chat/completions"


class GroqError(Exception):
    def __init__(self, message: str, *, status_code: int | None = None):
        super().__init__(message)
        self.status_code = status_code


def chat_completion(
    *,
    api_key: str,
    model: str,
    messages: list[dict[str, str]],
    temperature: float = 0.3,
    max_tokens: int = 700,
    timeout_seconds: float = 45.0,
) -> str:
    if not api_key.strip():
        raise GroqError("GROQ_API_KEY is not configured", status_code=503)
    if not messages:
        raise GroqError("messages are required", status_code=400)

    payload: dict[str, Any] = {
        "model": model,
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_tokens,
    }
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        GROQ_CHAT_URL,
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key.strip()}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "crgs-backend/1.0",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=timeout_seconds) as resp:
            raw = resp.read().decode("utf-8")
            data = json.loads(raw)
    except urllib.error.HTTPError as exc:
        detail = ""
        try:
            err_body = exc.read().decode("utf-8", errors="replace")
            parsed = json.loads(err_body)
            detail = str(
                (parsed.get("error") or {}).get("message")
                or parsed.get("error")
                or err_body
            )[:400]
        except Exception:  # noqa: BLE001
            detail = str(exc.reason)
        logger.warning("Groq HTTP %s: %s", exc.code, detail)
        raise GroqError(
            detail or f"Groq request failed ({exc.code})",
            status_code=502,
        ) from exc
    except urllib.error.URLError as exc:
        logger.warning("Groq network error: %s", exc)
        raise GroqError("Could not reach Groq API", status_code=502) from exc
    except TimeoutError as exc:
        raise GroqError("Groq request timed out", status_code=504) from exc

    try:
        content = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise GroqError("Unexpected Groq response shape", status_code=502) from exc

    text = str(content or "").strip()
    if not text:
        raise GroqError("Empty response from Groq", status_code=502)
    return text
