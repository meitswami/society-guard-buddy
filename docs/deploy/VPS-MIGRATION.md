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

## 1. DNS
Create an **A record** (and AAAA for IPv6) for the domain you want, e.g. `app.kutumbika.in`, pointing at the VPS IP.
Wait until `ping app.kutumbika.in` shows the VPS IP.

## 2. Server (once)
```bash
# on the VPS (Ubuntu/Debian), from a checkout or a copy of deploy/vps/
sudo bash deploy/vps/setup-server.sh app.kutumbika.in you@example.com deploy
```
If the VPS already runs nginx for other Brandzaha sites, this only **adds** `/etc/nginx/sites-available/kutumbika.conf`. Other sites are untouched.

## 3. Deploy key
```bash
ssh-keygen -t ed25519 -C "github-deploy" -f kutumbika_deploy -N ""
# put the public key on the server:
sudo tee -a /home/deploy/.ssh/authorized_keys < kutumbika_deploy.pub
ssh-keyscan -H app.kutumbika.in   # copy the output for VPS_KNOWN_HOSTS
```

## 4. GitHub settings (Settings → Secrets and variables → Actions)
**Secrets**

| Name | Value |
|---|---|
| `VPS_HOST` | `app.kutumbika.in` (or the IP) |
| `VPS_USER` | `deploy` |
| `VPS_SSH_KEY` | contents of `kutumbika_deploy` (private key) |
| `VPS_PORT` | optional, default 22 |
| `VPS_KNOWN_HOSTS` | optional, output of `ssh-keyscan` |
| `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY` | copy from Vercel → Project → Settings → Environment Variables |
| `VITE_FIREBASE_API_KEY`, `VITE_FIREBASE_AUTH_DOMAIN`, `VITE_FIREBASE_PROJECT_ID`, `VITE_FIREBASE_STORAGE_BUCKET`, `VITE_FIREBASE_MESSAGING_SENDER_ID`, `VITE_FIREBASE_APP_ID`, `VITE_FIREBASE_MEASUREMENT_ID`, `VITE_FIREBASE_VAPID_KEY` | copy from Vercel |
| `VITE_RECAPTCHA_ENTERPRISE_SITE_KEY`, `VITE_RECAPTCHA_ASSESSMENT_STRICT` | copy from Vercel (if set) |

**Variables**: `VPS_PATH` = `/var/www/kutumbika` (default), `VPS_PUBLIC_URL` = `https://app.kutumbika.in` (used for the health check).

## 5. First deploy
GitHub → Actions → **Deploy web to VPS** → *Run workflow*. After that, every push to `main` deploys automatically.

## 6. Settings that use the domain (do these before switching users over)
1. **Firebase → Authentication → Settings → Authorized domains**: add `app.kutumbika.in`. Phone OTP login fails without it.
2. **reCAPTCHA Enterprise key** (Google Cloud → Security → reCAPTCHA): add the new domain to the key's domain list.
3. **Supabase → Edge Functions → Secrets**: set `PUBLIC_SITE_URL=https://app.kutumbika.in`, then redeploy `phonepe-init-order`. PhonePe returns users to this URL after paying for a new-society signup.
4. **Google Cloud → APIs & Services → Credentials**: if the browser API key has *HTTP referrer* restrictions, add `https://app.kutumbika.in/*`.
5. Mobile app: set `WEB_APP_URL=https://app.kutumbika.in` in `mobile/.env` (or the `APP_ENV` CI secret). The app opens legal pages and signup there.

## 7. Switch over
Open `https://app.kutumbika.in`, then test: login (password + OTP), the AI kiosk camera and mic, a PhonePe test signup, and push notifications.
When everything works, point any old links to the new domain. Then remove the Vercel project, or leave it redirecting.

## Rollback
```bash
ssh deploy@app.kutumbika.in 'cd /var/www/kutumbika && ls -1dt releases/*/'   # list releases
ssh deploy@app.kutumbika.in 'cd /var/www/kutumbika && ln -sfn releases/<older-id> current.next && mv -Tf current.next current'
```

## Docker alternative
```bash
cp .env.example deploy/vps/.env   # fill the VITE_* values
docker compose -f deploy/vps/docker-compose.yml up -d --build   # serves on 127.0.0.1:8088
```
Point your existing reverse proxy (nginx / Caddy / Traefik) at `127.0.0.1:8088`.
