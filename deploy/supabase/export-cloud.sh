#!/usr/bin/env bash
# Step 1 — export the Supabase cloud database (schema + data + custom roles).
# Run on the VPS (needs Docker and Node 18+). Takes a few minutes.
#
#   export OLD_DB_URL='postgresql://postgres.cyydprpucjeiscetrdfa:<DB-PASSWORD>@aws-0-<region>.pooler.supabase.com:5432/postgres'
#   bash export-cloud.sh /opt/kutumbika-supabase/migration
#
# OLD_DB_URL: Supabase dashboard → Connect → "Session pooler" connection string (port 5432),
# with your database password filled in.
set -euo pipefail
OUT="${1:-./migration}"
: "${OLD_DB_URL:?Set OLD_DB_URL to the cloud session-pooler connection string}"
mkdir -p "$OUT"
cd "$OUT"
echo "==> Roles";  npx --yes supabase@latest db dump --db-url "$OLD_DB_URL" -f roles.sql --role-only
echo "==> Schema"; npx --yes supabase@latest db dump --db-url "$OLD_DB_URL" -f schema.sql
echo "==> Data";   npx --yes supabase@latest db dump --db-url "$OLD_DB_URL" -f data.sql --use-copy --data-only
ls -lh roles.sql schema.sql data.sql
echo "Done. Next: bash import-selfhost.sh $OUT"
