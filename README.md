# Songwriter

Record a song on guitar or piano and get an editable lead sheet PDF. The spec
is in [`docs/PRD.md`](docs/PRD.md); build status is in [`CLAUDE.md`](CLAUDE.md).

## Layout

| Path | What |
| --- | --- |
| `apps/web` | Next.js app (App Router, TypeScript strict, Tailwind), deployed on Vercel |
| `worker` | Python 3.11 functions on Modal |
| `shared` | Chord fixtures used by both test suites |
| `supabase` | Migrations, RLS policies, database tests |
| `testdata` | Evaluation labels (audio is gitignored) |

## Local setup

Requires Node 22+, [uv](https://docs.astral.sh/uv/), Docker (for the local database) and `psql`.

```sh
cp .env.example apps/web/.env.local   # fill in values
npm install
(cd worker && uv sync)
```

| Task | Command |
| --- | --- |
| Web dev server | `npm run dev` |
| Web tests / typecheck | `npm test`, `npm run typecheck` |
| Worker tests / lint | `cd worker && uv run pytest && uv run ruff check . && uv run ruff format --check .` |
| Database tests (migrations + RLS) | `npm run test:db` |

## Supabase

```sh
npx supabase login
npx supabase link --project-ref <project-ref>
npx supabase db push            # applies supabase/migrations
```

In the dashboard, enable the Email provider (magic link) under Authentication.

## Modal

```sh
cd worker
uv run modal token new
uv run modal secret create songwriter-worker WORKER_SECRET=<same value as the web app>
uv run modal deploy app.py
curl -H "X-Worker-Secret: <secret>" https://<workspace>--songwriter-worker.modal.run/hello
```

The deploy prints the endpoint URL; set it as `MODAL_ENDPOINT_URL`.
