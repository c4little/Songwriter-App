"""Shared-secret check for Modal web endpoints (PRD section 10, X-Worker-Secret)."""

import hmac

WORKER_SECRET_HEADER = "X-Worker-Secret"


def is_authorized(provided: str | None, expected: str | None) -> bool:
    """Constant-time compare; fails closed when either side is missing or empty."""
    if not provided or not expected:
        return False
    return hmac.compare_digest(provided.encode(), expected.encode())
