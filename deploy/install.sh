#!/usr/bin/env bash
# Deploy the public Onward repository to an existing Ubuntu/Nginx server.
# Uses an existing Let's Encrypt account and never changes other virtual hosts.
set -Eeuo pipefail
DOMAIN="${1:-english.blackmstone.site}"
REPO_URL="${ONWARD_REPO_URL:-https://github.com/valarxu/onward-english.git}"
APP_DIR=/opt/onward-english
WEB_DIR=/var/www/onward-english
CONF=/etc/nginx/sites-available/onward-english
ENABLED=/etc/nginx/sites-enabled/onward-english
if [[ "$EUID" -ne 0 ]]; then echo 'Run with sudo or as root.' >&2; exit 1; fi
if [[ ! "$DOMAIN" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ || "$DOMAIN" != *.* ]]; then echo 'Invalid domain.' >&2; exit 1; fi
for bin in git nginx certbot python3 curl; do command -v "$bin" >/dev/null || { echo "Missing prerequisite: $bin" >&2; exit 1; }; done
# Detect another site's configuration claiming this exact name.
if grep -rlE "server_name[[:space:]][^;]*\\b${DOMAIN//./\\.}([[:space:];]|$)" /etc/nginx/sites-enabled/ 2>/dev/null | grep -qv '^/etc/nginx/sites-enabled/onward-english$'; then
    echo 'This domain already exists in another Nginx configuration; inspect it before deploying.' >&2; exit 1
fi
nginx -t
if [[ -e "$APP_DIR" && ! -d "$APP_DIR/.git" ]]; then echo "$APP_DIR exists and is not a Git checkout." >&2; exit 1; fi
if [[ ! -d "$APP_DIR/.git" ]]; then git clone --branch main "$REPO_URL" "$APP_DIR"; fi
[[ "$(git -C "$APP_DIR" remote get-url origin)" == "$REPO_URL" ]] || { echo 'Unexpected repository remote.' >&2; exit 1; }
[[ -z "$(git -C "$APP_DIR" status --porcelain)" ]] || { echo 'Deployment checkout has local changes; preserve and resolve them first.' >&2; exit 1; }
git -C "$APP_DIR" fetch origin main
git -C "$APP_DIR" merge --ff-only origin/main
if command -v node >/dev/null; then (cd "$APP_DIR" && node --check dist/app.js && node scripts/validate.mjs); fi
REV="$(git -C "$APP_DIR" rev-parse HEAD)"
RELEASE="$WEB_DIR/releases/$REV"
mkdir -p "$RELEASE" "$WEB_DIR/acme/.well-known/acme-challenge"
cp -a "$APP_DIR/dist/." "$RELEASE/"
find "$RELEASE" -type d -exec chmod 755 {} +
find "$RELEASE" -type f -exec chmod 644 {} +
# Keep the previous path available for rollback; switch the static release atomically.
PREVIOUS="$(readlink "$WEB_DIR/current" 2>/dev/null || true)"
ln -sfn "$RELEASE" "$WEB_DIR/current.next"
mv -Tf "$WEB_DIR/current.next" "$WEB_DIR/current"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP=''
if [[ -e "$CONF" ]]; then BACKUP="$CONF.backup.$STAMP"; cp -p "$CONF" "$BACKUP"; fi
restore_config() {
    if [[ -n "$BACKUP" ]]; then cp -p "$BACKUP" "$CONF"; else rm -f "$ENABLED" "$CONF"; fi
    if [[ -n "$PREVIOUS" ]]; then ln -sfn "$PREVIOUS" "$WEB_DIR/current.next"; mv -Tf "$WEB_DIR/current.next" "$WEB_DIR/current"; fi
    if nginx -t; then systemctl reload nginx; fi
}
TMP_CONF="$(mktemp /etc/nginx/sites-available/.onward-english.XXXXXX)"
trap 'rm -f "$TMP_CONF"' EXIT
# Bootstrap HTTP only when a certificate does not yet exist.
if [[ ! -s "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
cat > "$TMP_CONF" <<HTTP
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    root $WEB_DIR/current;
    index index.html;
    location ^~ /.well-known/acme-challenge/ { root $WEB_DIR/acme; default_type text/plain; try_files \$uri =404; }
    location / { try_files \$uri \$uri/ =404; }
}
HTTP
    install -m 644 "$TMP_CONF" "$CONF"
    ln -sfn "$CONF" "$ENABLED"
    if ! nginx -t; then restore_config; exit 1; fi
    systemctl reload nginx
fi
# Reuse an existing production account; no registration or terms acceptance here.
ACCOUNT="$(python3 - <<'PY'
from pathlib import Path
import re
for p in sorted(Path('/etc/letsencrypt/renewal').glob('*.conf')):
    text=p.read_text()
    if 'acme-v02.api.letsencrypt.org' in text:
        m=re.search(r'^account\s*=\s*([a-f0-9]+)\s*$',text,re.M)
        if m:
            print(m.group(1));break
PY
)"
if [[ -z "$ACCOUNT" ]]; then echo 'No existing production ACME account found. Configure one before requesting a certificate.' >&2; exit 1; fi
certbot certonly --webroot --webroot-path "$WEB_DIR/acme" --domain "$DOMAIN" --cert-name "$DOMAIN" --account "$ACCOUNT" --non-interactive --keep-until-expiring
sed "s/__DOMAIN__/$DOMAIN/g" "$APP_DIR/deploy/nginx.conf.template" > "$TMP_CONF"
# Nginx before 1.25.1 uses the http2 listen option instead of the http2 directive.
if ! nginx -v 2>&1 | python3 -c 'import re,sys; m=re.search(r"nginx/(\d+)\.(\d+)\.(\d+)",sys.stdin.read()); sys.exit(0 if m and tuple(map(int,m.groups())) >= (1,25,1) else 1)'; then
    sed -i -e 's/listen 443 ssl;/listen 443 ssl http2;/' -e 's/listen \[::\]:443 ssl;/listen [::]:443 ssl http2;/' -e '/^[[:space:]]*http2 on;/d' "$TMP_CONF"
fi
install -m 644 "$TMP_CONF" "$CONF"
ln -sfn "$CONF" "$ENABLED"
if ! nginx -t; then restore_config; exit 1; fi
systemctl reload nginx
mkdir -p /etc/letsencrypt/renewal-hooks/deploy
printf '%s\n' '#!/bin/sh' 'nginx -t && systemctl reload nginx' > /etc/letsencrypt/renewal-hooks/deploy/onward-english-nginx
chmod 755 /etc/letsencrypt/renewal-hooks/deploy/onward-english-nginx
if systemctl list-unit-files certbot.timer --no-legend 2>/dev/null | grep -q certbot.timer; then systemctl enable --now certbot.timer; fi
curl --fail --silent --show-error --resolve "$DOMAIN:443:127.0.0.1" "https://$DOMAIN/healthz"
printf '\nDeployed %s\nRevision: %s\nPrevious release: %s\n' "https://$DOMAIN" "$REV" "${PREVIOUS:-none}"
