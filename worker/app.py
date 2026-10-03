"""Modal app: functions and web endpoints (PRD sections 7 and 10).

Phase 0 only exposes an authenticated hello-world endpoint. process_song,
regenerate_section and render_pdf are added in phases 3 and 5.

Deploy:  modal deploy app.py
Dev:     modal serve app.py
Secrets: a Modal secret named "songwriter-worker" holding WORKER_SECRET (and,
         from phase 3, the other worker variables in .env.example).
"""

import modal

APP_NAME = "songwriter-worker"

image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install("fastapi[standard]>=0.115")
    .add_local_python_source("auth", "web", "config")
)

app = modal.App(APP_NAME, image=image)


@app.function(secrets=[modal.Secret.from_name("songwriter-worker")])
@modal.asgi_app(label="songwriter-worker")
def api() -> object:
    from web import create_web_app

    return create_web_app()
