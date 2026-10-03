#!/usr/bin/env bash
# Resets the local Supabase database (re-applies every migration) and runs the
# RLS tests against it. Requires Docker. Usage: scripts/test-db.sh
set -euo pipefail
cd "$(dirname "$0")/.."

DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"

if ! npx supabase status >/dev/null 2>&1 && ! pg_isready -d "$DB_URL" >/dev/null 2>&1; then
  npx supabase db start
fi
npx supabase db reset --local --no-seed
for f in supabase/tests/*.test.sql; do
  echo "== $f"
  psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$f"
done
