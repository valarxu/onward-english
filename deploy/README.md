# Ubuntu / Tencent Cloud deployment

This is a static site. Nginx serves `dist/`; learning records remain in each visitor's browser. No database, GitHub token, application secret or account service is required.

## Prerequisites

- Ubuntu with `git`, `nginx`, `certbot`, `python3`, and `curl` installed.
- An existing registered production Let's Encrypt account with at least one renewal config.
- DNS A record for `english.blackmstone.site` pointing to this server; ports 80 and 443 reachable.
- Root or sudo access.

## First deployment or update

```sh
curl -fsSL https://raw.githubusercontent.com/valarxu/onward-english/main/deploy/install.sh -o /tmp/onward-english-install.sh
sudo bash /tmp/onward-english-install.sh english.blackmstone.site
```

The script clones/pulls the public repository into `/opt/onward-english`, copies a static release into `/var/www/onward-english/releases/<commit>`, switches the `current` symlink, and creates only the `onward-english` Nginx virtual host. Existing unrelated sites are retained. A domain already configured in another virtual host causes a stop for inspection.

HTTPS uses a separate certificate for this domain, an existing ACME account, HTTP-to-HTTPS redirection, and a deploy hook that reloads Nginx after certificate renewal. Existing Certbot scheduling is reused; `certbot.timer` is enabled when available. The deployment script never registers a new ACME account or accepts terms on the operator's behalf.

## Checks

```sh
sudo nginx -t
curl -I http://english.blackmstone.site
curl -I https://english.blackmstone.site
curl -fsS https://english.blackmstone.site/healthz
sudo certbot certificates
systemctl status certbot.timer
```

To test certificate renewal without replacing the live certificate:

```sh
sudo certbot renew --cert-name english.blackmstone.site --dry-run
```

## Rollback

The deploy output prints the previous release directory. Point `/var/www/onward-english/current` back to that directory to restore the previous static release. Older Nginx configs are backed up next to `/etc/nginx/sites-available/onward-english` before replacement.

## Move existing learning records

Browser storage is scoped to the site's origin. On the old site, export learning records using **设置与备份 → 导出进度与笔记**, then import that JSON on the new HTTPS domain. Records are merged, rather than blindly replacing newer notes.
