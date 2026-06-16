# Bitir Yemek - Production Deployment (Hostinger VPS / Ubuntu)

This runbook deploys the **Bitir Yemek backend** (Node.js/Express + Sequelize/PostgreSQL + optional Redis) on a single Hostinger VPS running Ubuntu, behind a **shared Caddy reverse proxy** that can front multiple apps on the same box.

- **Path A - Docker Compose (recommended):** each app is its own compose stack (app + PostgreSQL + Redis); a single shared **Caddy** container terminates TLS and routes by domain.
- **Path B - PM2 (bare metal):** Node via nvm + system PostgreSQL + Redis + host **Caddy**.

This is a **single instance per app** deployment (not horizontally scaled). Do not run the app in cluster mode - the rate limiter is in-memory and the cron jobs must have a single owner.

### Why a shared proxy?

Ports 80/443 can be bound only once on the host. To run **multiple apps** on one VPS, a single reverse proxy owns 80/443 and routes each domain to the right app's container. Caddy is used because it **obtains and renews Let's Encrypt TLS automatically** - no certbot, no cron renewal. Adding a new app later = new compose stack + one block in the shared `Caddyfile` + a DNS record.

Architecture:

```
Internet :80/:443
   -> Caddy (shared proxy, auto-TLS)         [./proxy/]
        -> bitir-yemek-app:3000   (edge network)   [./docker-compose.yml]
             -> db, redis          (private bitir-net, never exposed)
        -> app2-app:8080  (edge network)            [another stack]
```

---

## 0. Prerequisites

- A Hostinger VPS (e.g. **KVM 2**: 2 vCPU / 8 GB RAM) with Ubuntu 22.04/24.04 and root access.
- A domain you control (e.g. `bitirgitsin.com`) so you can create a DNS A record per app (e.g. `api.bitirgitsin.com`).
- An SSH key pair on your local machine (`ssh-keygen -t ed25519` if you don't have one).

---

## 1. Initial server hardening

SSH in as root the first time:

```bash
ssh root@YOUR_VPS_IP
```

### 1.1 Create a non-root sudo user

```bash
adduser deploy
usermod -aG sudo deploy
```

### 1.2 Set up SSH key auth for that user

From your **local** machine:

```bash
ssh-copy-id deploy@YOUR_VPS_IP
```

Then on the server, harden SSH (`/etc/ssh/sshd_config`): set `PasswordAuthentication no` and `PermitRootLogin no`, then:

```bash
sudo systemctl restart ssh
```

Re-login as `deploy@YOUR_VPS_IP` and confirm `sudo` works before closing the root session.

### 1.3 Firewall (ufw)

```bash
sudo ufw allow 22/tcp     # SSH
sudo ufw allow 80/tcp     # HTTP (ACME challenge + redirect)
sudo ufw allow 443/tcp    # HTTPS
sudo ufw enable
sudo ufw status
```

> Do **not** open 3000, 5432, or 6379. The app, Postgres, and Redis are reached only via the shared Caddy proxy / the internal Docker network.

### 1.4 fail2ban (brute-force protection)

```bash
sudo apt update
sudo apt install -y fail2ban
sudo systemctl enable --now fail2ban
```

### 1.5 Keep packages current

```bash
sudo apt update && sudo apt upgrade -y
```

---

## 2. DNS

In your DNS provider, create one **A record per app**:

| Type | Name | Value |
|------|------|-------|
| A | `api` (→ `api.bitirgitsin.com`) | `YOUR_VPS_IP` |

Wait for propagation (`dig +short api.bitirgitsin.com` should return your VPS IP) **before** starting Caddy - TLS issuance needs the domain to resolve to this server.

---

# Path A - Docker Compose (recommended)

## 3A. Install Docker + Compose

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
# log out and back in so the group change takes effect
docker compose version   # confirms the v2 plugin is present
```

## 4A. Create the shared `edge` network (one-time)

Every app's public container and the shared proxy attach to this network:

```bash
docker network create edge
```

## 5A. Clone the repo

```bash
cd ~
git clone <YOUR_REPO_URL> bitir-yemek
cd bitir-yemek
```

## 6A. Create the `.env` file

```bash
cp .env.example .env
nano .env
```

Generate strong secrets:

```bash
openssl rand -hex 32   # JWT_SECRET
openssl rand -hex 32   # JWT_REFRESH_SECRET
openssl rand -hex 24   # REDIS_PASSWORD
openssl rand -hex 24   # POSTGRES_PASSWORD
```

Minimum production `.env` for the Docker path:

```ini
NODE_ENV=production
PORT=3000

# Postgres (used by compose for the db container AND by the app)
POSTGRES_DB=bitir_yemek
POSTGRES_USER=bitir
POSTGRES_PASSWORD=<openssl rand -hex 24>

# Redis password (compose injects REDIS_URL into the app automatically)
REDIS_PASSWORD=<openssl rand -hex 24>

# JWT - MUST be 32+ chars in production
JWT_SECRET=<openssl rand -hex 32>
JWT_REFRESH_SECRET=<openssl rand -hex 32>
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d

# CORS - comma-separated allowlist of web origins (the mobile app sends no Origin and is always allowed)
CORS_ORIGIN=https://bitirgitsin.com,https://www.bitirgitsin.com

# Swagger OFF in production
ENABLE_SWAGGER=false

# Sign-in providers
GOOGLE_CLIENT_ID=xxxxxxxx.apps.googleusercontent.com
APPLE_CLIENT_ID=com.bitirgitsin.app

# Email + maps
RESEND_API_KEY=re_xxxx
RESEND_FROM=Bitir Yemek <noreply@bitirgitsin.com>
GOOGLE_MAPS_API_KEY=AIza...
```

> The compose file overrides `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, and `REDIS_URL` so the app talks to the `db` and `redis` containers - you only need to set the `POSTGRES_*` and `REDIS_PASSWORD` values; you do not need to set `DATABASE_URL`.

## 7A. Bring up the app stack

```bash
docker compose up -d --build      # builds the app image, starts db + redis + app
docker compose ps                 # all healthy; app is on the "edge" network, not published
```

The app is now reachable **only** on the internal `edge` network as `bitir-yemek-app:3000` - nothing is public yet. The shared proxy (next step) exposes it.

## 8A. Configure + start the shared Caddy proxy (TLS is automatic)

The shared proxy lives in `./proxy/`. On a real server keep it in its own directory (e.g. copy `proxy/` to `/srv/proxy`) since it serves **all** apps, not just this one.

Edit `proxy/Caddyfile`:
- set the global `email` to a real address (Let's Encrypt notices),
- replace `api.bitiryemek.com` with your real domain.

Then start it:

```bash
cd proxy            # or: cd /srv/proxy
docker compose up -d
docker compose logs -f caddy     # watch it obtain the certificate
```

Caddy automatically requests and renews the TLS certificate for each domain in the `Caddyfile`, as long as the DNS A record points here and ports 80/443 are open.

## 9A. Run database migrations (explicitly)

Migrations are **never** run automatically. From the app stack directory:

```bash
cd ~/bitir-yemek
docker compose exec app npm run db:migrate
```

> **WARNING - never run `npm run db:seed` in production.** The seeders insert demo users/businesses (with known passwords) and are for local development only.

## 10A. Verify

```bash
curl -s https://api.bitirgitsin.com/api/health   # -> {"status":"ok","database":"connected",...}

# Confirm the proxy can reach the app over the edge network:
cd ~/bitir-yemek/proxy && docker compose exec caddy wget -qO- http://bitir-yemek-app:3000/api/health
```

## 11A. Update / redeploy

```bash
cd ~/bitir-yemek
git pull
docker compose up -d --build app
docker compose exec app npm run db:migrate   # only if new migrations landed
```

The shared proxy keeps running across app redeploys; you only touch it when adding/removing apps or changing domains.

## 12A. Adding another app later

1. Deploy the new app as its own compose stack, attaching its public container to the `edge` network with a network alias (e.g. `app2-app`). See `docker-compose.yml` here for the pattern (the `app` service joins both `bitir-net` and `edge`).
2. Append a block to `proxy/Caddyfile`:
   ```
   api.app2.com {
       reverse_proxy app2-app:8080
   }
   ```
3. Create the DNS A record `api.app2.com → YOUR_VPS_IP`.
4. Reload the proxy (zero downtime, auto-issues the new cert):
   ```bash
   cd /srv/proxy && docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
   ```

---

# Path B - PM2 (bare metal, no Docker)

## 3B. Install Node 20 (nvm), PostgreSQL, Redis, Caddy

```bash
# Node 20 via nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc
nvm install 20 && nvm use 20 && nvm alias default 20

# PostgreSQL + Redis
sudo apt install -y postgresql postgresql-contrib redis-server
sudo systemctl enable --now postgresql redis-server

# Caddy (official apt repo - auto-TLS, no certbot)
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
  | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
  | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install -y caddy

# PM2
npm install -g pm2
```

## 4B. Create the database

```bash
sudo -u postgres psql <<'SQL'
CREATE USER bitir WITH PASSWORD 'CHANGE_ME_STRONG';
CREATE DATABASE bitir_yemek OWNER bitir;
SQL
```

Secure Redis: set `requirepass <strong-password>` in `/etc/redis/redis.conf`, then `sudo systemctl restart redis-server`.

## 5B. Clone + install + configure

```bash
cd ~
git clone <YOUR_REPO_URL> bitir-yemek
cd bitir-yemek
npm ci --omit=dev
cp .env.example .env
nano .env
mkdir -p logs uploads
```

For the PM2 path, set the DB/Redis vars explicitly in `.env`:

```ini
NODE_ENV=production
PORT=3000

DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=bitir_yemek
DB_USER=bitir
DB_PASSWORD=CHANGE_ME_STRONG
DB_SSL=false

REDIS_URL=redis://default:CHANGE_ME_REDIS@127.0.0.1:6379

JWT_SECRET=<openssl rand -hex 32>
JWT_REFRESH_SECRET=<openssl rand -hex 32>
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d

CORS_ORIGIN=https://bitirgitsin.com,https://www.bitirgitsin.com
ENABLE_SWAGGER=false
GOOGLE_CLIENT_ID=xxxxxxxx.apps.googleusercontent.com
APPLE_CLIENT_ID=com.bitirgitsin.app
RESEND_API_KEY=re_xxxx
RESEND_FROM=Bitir Yemek <noreply@bitirgitsin.com>
GOOGLE_MAPS_API_KEY=AIza...
```

## 6B. Migrate, then start

```bash
npm run db:migrate          # explicit - never auto-run
# DO NOT run npm run db:seed in production (demo data only)

pm2 start ecosystem.config.js --env production
pm2 save
pm2 startup     # run the command it prints, to start on boot
```

## 7B. Host Caddy + TLS

Put a site block in `/etc/caddy/Caddyfile` pointing at the local app (use `proxy/Caddyfile` in this repo as the template - for bare metal the upstream is `127.0.0.1:3000`):

```caddy
{
    email iletisim@bitirgitsin.com
}

api.bitirgitsin.com {
    reverse_proxy 127.0.0.1:3000
    request_body { max_size 6MB }
    encode gzip
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options nosniff
        X-Frame-Options SAMEORIGIN
        Referrer-Policy strict-origin-when-cross-origin
        -Server
    }
}

# Add another app: append a block with a different domain + local port.
# api.app2.com { reverse_proxy 127.0.0.1:8080 }
```

```bash
sudo nano /etc/caddy/Caddyfile      # paste the above, set your domain + email
sudo systemctl reload caddy         # auto-issues TLS for the domain
```

## 8B. Verify

```bash
curl -s https://api.bitirgitsin.com/api/health
pm2 logs bitir-yemek
pm2 status
sudo systemctl status caddy
```

## 9B. Update / redeploy

```bash
cd ~/bitir-yemek
git pull
npm ci --omit=dev
npm run db:migrate          # only if new migrations landed
pm2 reload bitir-yemek
```

---

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `NODE_ENV` | Yes | Set to `production`. |
| `PORT` | No (default 3000) | Port the app listens on. |
| `DB_HOST` | Yes* | Postgres host (`db` in compose, `127.0.0.1` for PM2). *Not needed if `DATABASE_URL` is set. |
| `DB_PORT` | Yes* | Postgres port (5432). |
| `DB_NAME` | Yes* | Database name. |
| `DB_USER` | Yes* | Database user. |
| `DB_PASSWORD` | Yes* | Database password. |
| `DATABASE_URL` | Alt | Full connection string; replaces the individual `DB_*` vars if set. |
| `DB_SSL` | No | `true` to force SSL to Postgres. Off by default; leave off for local/VPS Postgres. |
| `JWT_SECRET` | Yes | JWT signing secret. **Must be 32+ chars in production.** Generate with `openssl rand -hex 32`. |
| `JWT_REFRESH_SECRET` | Yes | Refresh-token signing secret. `openssl rand -hex 32`. |
| `JWT_EXPIRES_IN` | No | Access token TTL (e.g. `15m`). |
| `JWT_REFRESH_EXPIRES_IN` | No | Refresh token TTL (e.g. `7d`). |
| `CORS_ORIGIN` | Yes (web) | Comma-separated allowlist of browser origins. The mobile app sends no Origin and is always allowed. In production an undefined value blocks cross-origin browser requests. |
| `ENABLE_SWAGGER` | No | Swagger UI is **off** in production unless this is `true`. Keep off in prod. |
| `GOOGLE_CLIENT_ID` | Recommended | Google Sign-In client ID. |
| `APPLE_CLIENT_ID` | Recommended | Apple Sign-In audience/client ID (e.g. `com.bitirgitsin.app`). Required for Apple login to work. |
| `RESEND_API_KEY` | Recommended | Resend API key for transactional email (OTP login codes, order status). |
| `RESEND_FROM` | Recommended | Sender address (e.g. `Bitir Yemek <noreply@domain>`); the sending domain must be verified in Resend. |
| `GOOGLE_MAPS_API_KEY` | Recommended | Used by the `/api/maps/*` geocoding/directions endpoints. |
| `REDIS_URL` | Prod-recommended | Redis connection string. In production, refresh-token revocation fails closed when Redis is down. Compose sets this automatically. |
| `POSTGRES_DB` / `POSTGRES_USER` / `POSTGRES_PASSWORD` | Compose only | Consumed by the `db` container and interpolated into the app's `DB_*` in `docker-compose.yml`. |
| `REDIS_PASSWORD` | Compose only | Sets the Redis password and is interpolated into `REDIS_URL`. |

\* Either the five `DB_*` vars **or** `DATABASE_URL` must be provided.

---

## Database backups (pg_dump cron)

### Docker Compose

Create `~/backup-db.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd ~/bitir-yemek
mkdir -p ~/backups
STAMP=$(date +%F_%H%M)
docker compose exec -T db pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" \
  | gzip > ~/backups/bitir_yemek_$STAMP.sql.gz
# keep only the last 14 days
find ~/backups -name 'bitir_yemek_*.sql.gz' -mtime +14 -delete
```

### PM2 / bare metal

```bash
#!/usr/bin/env bash
set -euo pipefail
mkdir -p ~/backups
STAMP=$(date +%F_%H%M)
PGPASSWORD="$DB_PASSWORD" pg_dump -h 127.0.0.1 -U bitir bitir_yemek \
  | gzip > ~/backups/bitir_yemek_$STAMP.sql.gz
find ~/backups -name 'bitir_yemek_*.sql.gz' -mtime +14 -delete
```

Make it executable and schedule it daily at 02:30 via `crontab -e`:

```cron
30 2 * * * /home/deploy/backup-db.sh >> /home/deploy/backups/backup.log 2>&1
```

Restore example (Docker):

```bash
gunzip -c ~/backups/bitir_yemek_2026-06-15_0230.sql.gz \
  | docker compose exec -T db psql -U "$POSTGRES_USER" "$POSTGRES_DB"
```

---

## Health checks & logs

| What | Command |
|------|---------|
| Health endpoint | `curl -s https://api.bitirgitsin.com/api/health` (200 = DB up, 503 = DB down) |
| App logs (Docker) | `docker compose logs -f app` |
| App logs (PM2) | `pm2 logs bitir-yemek` |
| Proxy logs (Docker) | `cd /srv/proxy && docker compose logs -f caddy` |
| Proxy logs (host) | `sudo journalctl -u caddy -f` |
| Container status | `docker compose ps` |
| Process status | `pm2 status` |

---

## Manual steps checklist

- [ ] Create non-root sudo user + SSH key, disable password/root SSH login.
- [ ] Configure `ufw` (22/80/443) and `fail2ban`.
- [ ] Create the DNS **A record** for `api.<your-domain>` → VPS IP (one per app).
- [ ] (Docker) `docker network create edge` once.
- [ ] Generate `JWT_SECRET`, `JWT_REFRESH_SECRET`, `POSTGRES_PASSWORD`, `REDIS_PASSWORD` with `openssl rand`.
- [ ] Set `CORS_ORIGIN` to your real web origin(s) and `APPLE_CLIENT_ID` / `GOOGLE_CLIENT_ID`.
- [ ] Set the `email` and real domain(s) in `proxy/Caddyfile` (or `/etc/caddy/Caddyfile` for PM2). TLS is automatic - no certbot.
- [ ] Run `npm run db:migrate` explicitly. **Never** run `npm run db:seed` in production.
- [ ] Confirm `/api/health` returns `200` over HTTPS.
- [ ] Set up the daily `pg_dump` backup cron.
