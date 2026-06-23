"""
Lightweight in-memory rate limiter for the EleFit FastAPI backend.

Why: /analyze-meal (OpenAI Vision), /chat, /mealplan, /workoutplan and /user all
call paid LLM APIs. The endpoints are public, so without limits a single client
(or a scraper that finds the URL) can run up real cost. This adds:

  * Per-IP throttling   — works with no app changes (backstop against abuse)
  * Per-user throttling  — when the client sends an "X-User-Id" header (Firebase UID)
  * Optional API-key gate — for Flutter-only endpoints (e.g. /analyze-meal)

In-memory is fine for a single Render instance. If you later run multiple
instances, swap the _HITS store for Redis (same interface).
"""

import os
import time
from collections import defaultdict, deque
from fastapi import Request, HTTPException

# ── Per-endpoint limits ──────────────────────────────────────────────────────
# ip_per_hour : max calls from one IP per rolling hour
# user_per_day: max calls from one user (X-User-Id) per rolling 24h
LIMITS = {
    "analyze-meal": {"ip_per_hour": 30, "user_per_day": 20},
    "chat":         {"ip_per_hour": 60, "user_per_day": 50},
    "mealplan":     {"ip_per_hour": 40, "user_per_day": 20},
    "workoutplan":  {"ip_per_hour": 40, "user_per_day": 20},
    "user":         {"ip_per_hour": 40, "user_per_day": 20},
}

# Shared secret the Flutter app sends as "X-API-Key". Override via env in prod.
API_KEY = os.getenv("ELEFIT_API_KEY", "elefit_flutter_secure_key_2025")

# key -> deque[timestamps]
_HITS: dict[str, deque] = defaultdict(deque)
# Safety cap so the dict can't grow unbounded under a key-spraying attack.
_MAX_KEYS = 50_000


def _client_ip(request: Request) -> str:
    """Render/most proxies set X-Forwarded-For; fall back to the socket peer."""
    fwd = request.headers.get("x-forwarded-for")
    if fwd:
        return fwd.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def _hit(key: str, limit: int, window: int) -> None:
    """Record one hit for `key`; raise 429 if it exceeds `limit` within `window` secs."""
    now = time.time()
    dq = _HITS[key]
    while dq and now - dq[0] > window:
        dq.popleft()
    if len(dq) >= limit:
        retry = int(window - (now - dq[0])) + 1
        raise HTTPException(
            status_code=429,
            detail="Too many requests. Please slow down and try again later.",
            headers={"Retry-After": str(retry)},
        )
    dq.append(now)
    # Opportunistic cleanup of fully-expired empty buckets.
    if len(_HITS) > _MAX_KEYS:
        for k in [k for k, v in list(_HITS.items()) if not v]:
            _HITS.pop(k, None)


def enforce(request: Request, scope: str) -> None:
    """Apply the configured IP + user limits for an endpoint `scope`.

    Call at the very top of an endpoint, e.g. `enforce(request, "analyze-meal")`.
    """
    cfg = LIMITS.get(scope, {"ip_per_hour": 60, "user_per_day": 50})

    ip = _client_ip(request)
    _hit(f"ip:{scope}:{ip}", cfg["ip_per_hour"], 3600)

    user_id = request.headers.get("x-user-id")
    if user_id:
        _hit(f"user:{scope}:{user_id}", cfg["user_per_day"], 86400)


def require_api_key(request: Request) -> None:
    """Reject requests without the shared X-API-Key. Use on Flutter-only endpoints.

    Do NOT use on endpoints the web app also calls (/chat, /mealplan, /workoutplan,
    /user) unless the web app is updated to send the key too.
    """
    if request.headers.get("x-api-key") != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid or missing API key.")
