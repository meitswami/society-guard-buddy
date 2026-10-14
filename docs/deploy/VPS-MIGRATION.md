# Moving the web app from Vercel to the Brandzaha VPS

The web app is a static React/Vite build, so the VPS only needs **nginx** to serve it. The backend stays on Supabase and nothing there moves.
Vercel can keep running until the new domain works, so there is no downtime.

Files in this repo:

| File | Purpose |
|---|---|
| `deploy/vps/setup-server.sh` | One-time server setup: nginx, Let's Encrypt HTTPS, deploy user, release folders |
| `deploy/vps/nginx/kutumbika.conf` | nginx site: SPA fallback (same as `vercel.json`), caching, `.wasm`/`.tflite` MIME types for the AI kiosk, security headers |
| `.github/workflows/deploy-web-vps.yml` | Builds the app and deploys it on every push to `main` (or a manual run). Keeps 5 releases for rollback |
| `deploy/vps/Dockerfile`, `docker-compose.yml` | Alternative if the VPS already runs everything in Docker behind a reverse proxy |

## 1. DNS (done)
The A record `kutumbika.meitcybersolutions.com` → `187.127.185.243` already exists.

## 2. Register the project in the VPS Panel
Panel → **Projects → New project**:

| Field | Value |
|---|---|
| Folder name | `kutumbika` (creates `/var/www/kutumbika`) |
| Display name | `Kutumbika - Ghar jaisa pariwar` |
| Description | `Society Management System` |
| GitHub repository | `https://github.com/meitswami/society-guard-buddy` (private repo: add the panel's deploy key in GitHub → Settings → Deploy keys first, or leave empty) |
| Port | **clear it**. The web app is a static site served by nginx; port 3004 is not needed |

Then on the VPS, set up nginx (SPA routes, kiosk `.wasm` / `.tflite` types, caching) and HTTPS for the domain.
If the panel cloned the repo, run:
```bash
sudo bash /var/www/kutumbika/deploy/vps/setup-server.sh kutumbika.meitcybersolutions.com you@example.com deploy
```
This writes `/etc/nginx/sites-available/kutumbika.conf` with `root /var/www/kutumbika/current`, gets the Let's Encrypt
certificate and creates the `deploy` user that GitHub Actions logs in as. It leaves the panel's files (`BRAIN.md`, the
clone) alone. If the panel already made its own nginx file for this domain, remove that one so there is only one
`server_name kutumbika.meitcybersolutions.com`:
```bash
grep -rl "kutumbika.meitcybersolutions.com" /etc/nginx/sites-enabled/
```
Then run `sudo nginx -t && sudo systemctl reload nginx`.

## 3. Deploy key for GitHub Actions
```bash
ssh-keygen -t ed25519 -C "github-deploy" -f kutumbika_deploy -N ""
# put the public key on the server:
sudo tee -a /home/deploy/.ssh/authorized_keys < kutumbika_deploy.pub
ssh-keyscan -H 187.127.185.243   # copy the output for VPS_KNOWN_HOSTS
```

## 4. GitHub settings (Settings → Secrets and variables → Actions)
**Secrets**

| Name | Value |
|---|---|
| `VPS_HOST` | `187.127.185.243` |
| `VPS_USER` | `deploy` |
| `VPS_SSH_KEY` | contents of `kutumbika_deploy` (private key) |
| `VPS_PORT` | optional, default 22 |
| `VPS_KNOWN_HOSTS` | optional, output of `ssh-keyscan` |
| `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY` | copy from Vercel → Project → Settings → Environment Variables |
| `VITE_FIREBASE_API_KEY`, `VITE_FIREBASE_AUTH_DOMAIN`, `VITE_FIREBASE_PROJECT_ID`, `VITE_FIREBASE_STORAGE_BUCKET`, `VITE_FIREBASE_MESSAGING_SENDER_ID`, `VITE_FIREBASE_APP_ID`, `VITE_FIREBASE_MEASUREMENT_ID`, `VITE_FIREBASE_VAPID_KEY` | copy from Vercel |
| `VITE_RECAPTCHA_ENTERPRISE_SITE_KEY`, `VITE_RECAPTCHA_ASSESSMENT_STRICT` | copy from Vercel (if set) |

**Variables**: `VPS_PATH` = `/var/www/kutumbika` (default), `VPS_PUBLIC_URL` = `https://kutumbika.meitcybersolutions.com` (used for the health check).

## 5. First deploy
GitHub → Actions → **Deploy web to VPS** → *Run workflow*. After that, every push to `main` deploys automatically.

The database can move to the VPS as well: see [SUPABASE-SELF-HOST.md](./SUPABASE-SELF-HOST.md).

## 6. Settings that use the domain (do these before switching users over)
1. **Firebase → Authentication → Settings → Authorized domains**: add `kutumbika.meitcybersolutions.com`. Phone OTP login fails without it.
2. **reCAPTCHA Enterprise key** (Google Cloud → Security → reCAPTCHA): add the new domain to the key's domain list.
3. **Supabase → Edge Functions → Secrets**: set `PUBLIC_SITE_URL=https://kutumbika.meitcybersolutions.com`, then redeploy `phonepe-init-order`. PhonePe returns users to this URL after paying for a new-society signup.
4. **Google Cloud → APIs & Services → Credentials**: if the browser API key has *HTTP referrer* restrictions, add `https://kutumbika.meitcybersolutions.com/*`.
5. Mobile app: set `WEB_APP_URL=https://kutumbika.meitcybersolutions.com` in `mobile/.env` (or the `APP_ENV` CI secret). The app opens legal pages and signup there.

## 7. Switch over
Open `https://kutumbika.meitcybersolutions.com`, then test: login (password + OTP), the AI kiosk camera and mic, a PhonePe test signup, and push notifications.
When everything works, point any old links to the new domain. Then remove the Vercel project, or leave it redirecting.

## Rollback
```bash
ssh deploy@kutumbika.meitcybersolutions.com 'cd /var/www/kutumbika && ls -1dt releases/*/'   # list releases
ssh deploy@kutumbika.meitcybersolutions.com 'cd /var/www/kutumbika && ln -sfn releases/<older-id> current.next && mv -Tf current.next current'
```

## Docker alternative
```bash
cp .env.example deploy/vps/.env   # fill the VITE_* values
docker compose -f deploy/vps/docker-compose.yml up -d --build   # serves on 127.0.0.1:8088
```
Point your existing reverse proxy (nginx / Caddy / Traefik) at `127.0.0.1:8088`.
