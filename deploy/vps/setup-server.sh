#!/usr/bin/env bash
# One-time setup of the Brandzaha VPS for the Kutumbika web app (Ubuntu / Debian).
# Usage (as root or with sudo):  sudo bash setup-server.sh app.yourdomain.in you@email.com deploy
#   $1 domain  (DNS A/AAAA record must already point at this server)
#   $2 email   (Let's Encrypt notices)
#   $3 deploy user that GitHub Actions logs in as (default: deploy)
set -euo pipefail

DOMAIN="${1:?domain required, e.g. app.kutumbika.in}"
EMAIL="${2:?email required for Lets Encrypt certificates}"
DEPLOY_USER="${3:-deploy}"
WEB_ROOT=/var/www/kutumbika
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "==> Installing nginx, certbot, rsync"
apt-get update -y
apt-get install -y nginx certbot python3-certbot-nginx rsync

echo "==> Deploy user '$DEPLOY_USER'"
if ! id "$DEPLOY_USER" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$DEPLOY_USER"
fi
mkdir -p "/home/$DEPLOY_USER/.ssh"
touch "/home/$DEPLOY_USER/.ssh/authorized_keys"
chmod 700 "/home/$DEPLOY_USER/.ssh"; chmod 600 "/home/$DEPLOY_USER/.ssh/authorized_keys"
chown -R "$DEPLOY_USER:$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"

echo "==> Web root $WEB_ROOT"
mkdir -p "$WEB_ROOT/releases"
if [ ! -e "$WEB_ROOT/current" ]; then
  mkdir -p "$WEB_ROOT/releases/initial"
  echo "<!doctype html><title>Kutumbika</title><p>Waiting for the first deploy…</p>" > "$WEB_ROOT/releases/initial/index.html"
  ln -sfn "$WEB_ROOT/releases/initial" "$WEB_ROOT/current"
fi
chown -R "$DEPLOY_USER:$DEPLOY_USER" "$WEB_ROOT"

echo "==> nginx site for $DOMAIN"
sed "s/app.example.com/$DOMAIN/g" "$HERE/nginx/kutumbika.conf" > /etc/nginx/sites-available/kutumbika.conf
ln -sfn /etc/nginx/sites-available/kutumbika.conf /etc/nginx/sites-enabled/kutumbika.conf
nginx -t
systemctl reload nginx

echo "==> HTTPS certificate"
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect

echo
echo "Done. Next:"
echo "  1. Put the GitHub Actions public key in /home/$DEPLOY_USER/.ssh/authorized_keys"
echo "  2. Add repo secrets VPS_HOST=$DOMAIN (or IP), VPS_USER=$DEPLOY_USER, VPS_SSH_KEY, VPS_PATH=$WEB_ROOT"
echo "  3. Run the 'Deploy web to VPS' workflow — see docs/deploy/VPS-MIGRATION.md"
