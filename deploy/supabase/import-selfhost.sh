#!/usr/bin/env bash
# Step 2 — load the export into the self-hosted Supabase database (one transaction).
#
#   bash import-selfhost.sh /opt/kutumbika-supabase/migration [/opt/kutumbika-supabase]
#
# Run it on a FRESH self-hosted stack (docker compose up -d done, nothing imported yet).
set -euo pipefail
IN="${1:?folder with roles.sql schema.sql data.sql}"
STACK="${2:-/opt/kutumbika-supabase}"
for f in roles.sql schema.sql data.sql; do [ -s "$IN/$f" ] || { echo "missing $IN/$f"; exit 1; }; done
COMBINED="$IN/combined.sql"
{
  cat "$IN/roles.sql"
  cat "$IN/schema.sql"
  echo "SET session_replication_role = replica;"
  cat "$IN/data.sql"
} > "$COMBINED"
cd "$STACK"
echo "==> Restoring into the self-hosted db container"
docker compose exec -T db psql -U postgres -d postgres --single-transaction -v ON_ERROR_STOP=1 < "$COMBINED"
echo "==> Post-import fixes (Edge Function URL, cron job)"
HERE="$(cd "$(dirname "$0")" && pwd)"
docker compose exec -T db psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -v api_url="${API_URL:?Set API_URL, e.g. https://api.kutumbika.meitcybersolutions.com}" < "$HERE/post-import.sql"
echo "Done. Next: copy the storage files — node migrate-storage.mjs"
