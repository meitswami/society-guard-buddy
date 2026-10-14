# Move the database from Supabase cloud to the Brandzaha VPS

This guide moves the whole backend (database, storage files, Edge Functions, realtime) from the
Supabase cloud project `cyydprpucjeiscetrdfa` to a self-hosted Supabase on the VPS
(`187.127.185.243`). The web app and the mobile app keep working the same way: only their
Supabase URL and key change.

| Item | Value |
|---|---|
| Web app | `https://kutumbika.meitcybersolutions.com` |
| API (new Supabase) | `https://api.kutumbika.meitcybersolutions.com` (new A record → `187.127.185.243`) |
| Stack folder on the VPS | `/opt/kutumbika-supabase` |
| Kong (API gateway) port | `127.0.0.1:8100`, because `8000` is already used by PaddleOCR |

Helper scripts are in `deploy/supabase/`.

> **Self-hosting means you own uptime and backups.** Supabase cloud did backups for you.
> Do step 9 (nightly backups) before you switch users over.

---

## 0. Before you start
1. DNS: add an **A record** `api.kutumbika` → `187.127.185.243`. Check it with `ping api.kutumbika.meitcybersolutions.com`.
2. Copy these from the Supabase dashboard (project `cyydprpucjeiscetrdfa`):
   - **Database password**: Project Settings → Database. Reset it if you don't know it.
   - **Session pooler connection string**: the **Connect** button → *Session pooler* (port 5432).
   - **service_role key**: Project Settings → API keys.
   - **Edge Function secrets**: Edge Functions → Secrets. Copy every value you have set, for example:
     - `FIREBASE_SERVICE_ACCOUNT_JSON`, `FIREBASE_API_KEY`
     - `RESEND_API_KEY`, `RESEND_FROM`
     - `WHATSAPP_ACCESS_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`
     - `ANTHROPIC_API_KEY`
     - `PHONEPE_*`
     - `RECAPTCHA_*`
     - `PUBLIC_SITE_URL`, `BACKUP_EMAIL`, `FEEDBACK_ALERT_EMAIL`, `MAINTENANCE_BILL_AUDIO_URL`
3. On the VPS, check which ports are free: `sudo ss -ltnp | grep -E ':(5432|5433|6543|8100|8543) '`.

## 1. Install the self-hosted Supabase stack
```bash
sudo mkdir -p /opt/kutumbika-supabase && cd /opt
sudo git clone --depth 1 https://github.com/supabase/supabase supabase-src
sudo cp -r supabase-src/docker/. /opt/kutumbika-supabase/
cd /opt/kutumbika-supabase
sudo cp .env.example .env
```

Generate the secrets. Run this from a checkout of this repo, on the VPS or your PC:
```bash
node deploy/supabase/gen-keys.mjs
```
Paste the printed lines into `/opt/kutumbika-supabase/.env`, replacing the template values. Then set:
```
SITE_URL=https://kutumbika.meitcybersolutions.com
API_EXTERNAL_URL=https://api.kutumbika.meitcybersolutions.com
SUPABASE_PUBLIC_URL=https://api.kutumbika.meitcybersolutions.com
KONG_HTTP_PORT=8100
KONG_HTTPS_PORT=8543
POSTGRES_PORT=5433          # pick a free port if 5432 is taken; never open it in the firewall
FUNCTIONS_VERIFY_JWT=false  # the app's functions run without Supabase Auth JWTs (same as cloud config.toml)
```

## 2. Edge Functions and their secrets
```bash
cd /opt/kutumbika-supabase
sudo cp -r /path/to/society-guard-buddy/supabase/functions/. volumes/functions/
```
Create `functions.env` and fill in the secrets you copied in step 0, one `KEY=value` per line.
For `FIREBASE_SERVICE_ACCOUNT_JSON`, put the whole JSON on one line inside single quotes.
```
FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
RESEND_API_KEY=...
WHATSAPP_ACCESS_TOKEN=...
PUBLIC_SITE_URL=https://kutumbika.meitcybersolutions.com
```
Then create `docker-compose.override.yml`:
```yaml
services:
  functions:
    env_file: ./functions.env
```

## 3. Start the stack
```bash
cd /opt/kutumbika-supabase
sudo docker compose pull
sudo docker compose up -d
sudo docker compose ps          # every service should be "healthy" after about a minute
```

## 4. HTTPS for the API
```bash
sudo cp /path/to/society-guard-buddy/deploy/supabase/nginx/kutumbika-api.conf /etc/nginx/sites-available/
sudo ln -sfn /etc/nginx/sites-available/kutumbika-api.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d api.kutumbika.meitcybersolutions.com --redirect
```
You can also add the certificate from the VPS Panel → **SSL**.

Test it: `curl https://api.kutumbika.meitcybersolutions.com/rest/v1/ -H "apikey: <ANON_KEY>"` should return JSON.
Studio (the database dashboard) is at `https://api.kutumbika.meitcybersolutions.com` and asks for `DASHBOARD_USERNAME` / `DASHBOARD_PASSWORD`.

## 5. Export the cloud database
Start the maintenance window here: from this point, new data written in the old app would not be copied.
```bash
cd /path/to/society-guard-buddy/deploy/supabase
export OLD_DB_URL='postgresql://postgres.cyydprpucjeiscetrdfa:<DB-PASSWORD>@aws-0-<region>.pooler.supabase.com:5432/postgres'
bash export-cloud.sh /opt/kutumbika-supabase/migration
```
This writes `roles.sql`, `schema.sql` and `data.sql` (Supabase's official `supabase db dump` method).

## 6. Import into the VPS
```bash
API_URL=https://api.kutumbika.meitcybersolutions.com \
  bash import-selfhost.sh /opt/kutumbika-supabase/migration /opt/kutumbika-supabase
```
It loads everything in one transaction, so a failure leaves the new database untouched. It then runs `post-import.sql`, which:
- points the visitor-approval push trigger at the new Edge Functions URL;
- recreates the monthly-maintenance cron job, because cron jobs are not part of a dump.

Quick check:
```bash
sudo docker compose exec db psql -U postgres -c "select count(*) from public.flats;" -c "select count(*) from public.members;"
```
Compare the counts with the cloud dashboard (Table editor).

## 7. Copy the Storage files
These are photos, receipts, documents and voice notes. Run from the repo root on the VPS, after `npm ci`:
```bash
OLD_URL=https://cyydprpucjeiscetrdfa.supabase.co OLD_SERVICE_KEY=<cloud service_role key> \
NEW_URL=https://api.kutumbika.meitcybersolutions.com NEW_SERVICE_KEY=<new SERVICE_ROLE_KEY> \
node deploy/supabase/migrate-storage.mjs
```
It is safe to run again; existing files are overwritten.

## 8. Switch the apps to the new backend
1. **Web (VPS)**: GitHub → Settings → Secrets → set `VITE_SUPABASE_URL=https://api.kutumbika.meitcybersolutions.com` and `VITE_SUPABASE_PUBLISHABLE_KEY=<new ANON_KEY>`. Then run **Deploy web to VPS**.
2. **Web (Vercel)**: set the same two variables in Vercel and redeploy, or turn Vercel into a redirect to the new domain. Otherwise the old site keeps writing to the cloud database.
3. **Mobile**: put `SUPABASE_URL` and `SUPABASE_ANON_KEY` with the new values in the `APP_ENV` GitHub secret (the full `mobile/.env` content). The next Android build uses them.
4. **Firebase console** → Authentication → Authorized domains: add `kutumbika.meitcybersolutions.com` (needed for phone OTP on the web).
5. **PhonePe**: set `PUBLIC_SITE_URL=https://kutumbika.meitcybersolutions.com` in `functions.env`, then run `docker compose up -d functions`.

Test login, a visitor entry with resident approval, a payment and a notification. When everything works, pause the cloud project. Keep it for a few weeks as a fallback before deleting it.

## 9. Nightly backups (do this before going live)
```bash
sudo mkdir -p /var/backups/kutumbika
sudo tee /etc/cron.d/kutumbika-backup >/dev/null <<'CRON'
30 2 * * * root cd /opt/kutumbika-supabase && docker compose exec -T db pg_dump -U postgres -Fc postgres > /var/backups/kutumbika/db-$(date +\%F).dump && tar -czf /var/backups/kutumbika/storage-$(date +\%F).tgz volumes/storage && find /var/backups/kutumbika -mtime +14 -delete
CRON
```
Copy `/var/backups/kutumbika` off the server regularly, for example with rclone to Google Drive.

Restore a backup:
```bash
docker compose exec -T db pg_restore -U postgres -d postgres --clean < db-YYYY-MM-DD.dump
```

## Rollback
Until you pause the cloud project, rolling back only means putting the old `VITE_SUPABASE_*` / `SUPABASE_*` values back and redeploying. Data written to the VPS in the meantime would have to be exported again.
