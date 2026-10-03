"""FastAPI app served by Modal. Kept separate from app.py so tests run without Modal."""

import os
from collections.abc import Callable
from typing import Annotated

from fastapi import FastAPI, Header, HTTPException

from auth import is_authorized


def create_web_app(get_secret: Callable[[], str | None] | None = None) -> FastAPI:
    secret = get_secret or (lambda: os.environ.get("WORKER_SECRET"))
    api = FastAPI(title="songwriter-worker", docs_url=None, redoc_url=None, openapi_url=None)

    def require_secret(provided: str | None) -> None:
        if not is_authorized(provided, secret()):
            raise HTTPException(status_code=401, detail="unauthorized")

    @api.get("/hello")
    def hello(
        x_worker_secret: Annotated[str | None, Header(alias="X-Worker-Secret")] = None,
    ) -> dict[str, str]:
        require_secret(x_worker_secret)
        return {"status": "ok", "service": "songwriter-worker"}

    return api
