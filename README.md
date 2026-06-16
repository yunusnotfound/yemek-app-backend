<div align="center">

# 🍽️ Bitir Yemek

**A food-waste-reduction marketplace** — restaurants and food businesses sell discounted "surprise packages" of surplus food; customers browse nearby deals, reserve, and pick them up with a code.

[![Node.js](https://img.shields.io/badge/Node.js-20+-339933?logo=node.js&logoColor=white)](https://nodejs.org)
[![Express](https://img.shields.io/badge/Express-4-000000?logo=express&logoColor=white)](https://expressjs.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Redis](https://img.shields.io/badge/Redis-7-DC382D?logo=redis&logoColor=white)](https://redis.io)
[![Flutter](https://img.shields.io/badge/Flutter-3-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](https://www.docker.com)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?logo=githubactions&logoColor=white)](#-devops--production-infrastructure)

</div>

---

## 📖 Overview

**Bitir Yemek** ("finish the food") tackles food waste by letting businesses list end-of-day surplus as discounted *surprise packages*. Customers near them discover offers on a map, reserve a package, and redeem it in-store with a pickup code — less waste for businesses, cheaper meals for customers.

This is a **full-stack monorepo**:

| Component | Stack | Path |
|-----------|-------|------|
| **Backend REST API** | Node.js · Express · PostgreSQL · Redis | [`/src`](./src) |
| **Mobile app (iOS + Android)** | Flutter · BLoC · Clean Architecture | [`/bitir_yemek_mobile`](./bitir_yemek_mobile) |
| **Infrastructure & DevOps** | Docker · Caddy · GitHub Actions · Grafana/Sentry | [`docker-compose.yml`](./docker-compose.yml) · [`DEPLOYMENT.md`](./DEPLOYMENT.md) |

---

## ✨ Features

**Customers**
- 🗺️ Discover nearby surprise packages on a map (Mapbox), filtered by distance/category
- 🔐 Passwordless login via email OTP, plus Google & Apple Sign-In
- 🛒 Reserve packages with atomic stock control (no overselling) and a pickup code
- ⭐ Favorites, reviews, coupons, and push-style in-app notifications

**Businesses**
- 🏪 Manage business profile, opening hours, and menu of packages
- ♻️ One-off or **recurring** packages (auto-generated daily from templates)
- 📦 Track and update order status (`pending → confirmed → picked_up`)
- 📊 Business dashboard with sales insights

**Admins**
- ✅ Approve businesses before they go live
- 👥 Full management surface via a dedicated admin API

---

## 🛠️ Tech Stack

### Backend
`Express` · `Sequelize` (PostgreSQL) · `Redis` (ioredis) · `JWT` access/refresh auth · `Zod` request validation · `bcrypt` · `Resend` transactional email · `node-cron` scheduled jobs · `Winston` structured logging · `Swagger` API docs · `i18next` (TR/EN) · `helmet` + rate limiting

### Mobile (Flutter)
`flutter_bloc` state management · **Clean Architecture** (data / domain / presentation) · `Dio` HTTP with auto token-refresh interceptor · `flutter_secure_storage` (Keychain / Keystore) · `Mapbox` · `google_sign_in` · `sign_in_with_apple` · `geolocator`

### DevOps / Infrastructure
`Docker Compose` · `Caddy` (automatic Let's Encrypt TLS) · `GitHub Actions` CI/CD · `Sentry` (errors + APM) · `Grafana Cloud` (Loki logs + Prometheus metrics via Alloy) · `PostgreSQL` automated backups

---

## 🏗️ Architecture

```
                              Internet  :443 (HTTPS)
                                   │
                      ┌────────────▼────────────┐
                      │   Caddy reverse proxy    │  auto-TLS, HSTS, gzip
                      │   (shared, multi-app)    │
                      └────────────┬────────────┘
                                   │  edge network
                      ┌────────────▼────────────┐
                      │   Express API (Node 20)  │  JWT · Zod · rate-limit
                      │   stateless, single inst.│
                      └─────┬───────────────┬────┘
                            │ private net   │
                    ┌───────▼──────┐  ┌─────▼──────┐
                    │ PostgreSQL16 │  │  Redis 7   │  refresh-token store,
                    │ (Sequelize)  │  │  (cache)   │  cache (fail-closed)
                    └──────────────┘  └────────────┘

   Mobile (Flutter, Clean Arch + BLoC)  ──HTTPS──►  /api/*
```

**Backend** follows a layered Express structure — `routes → middlewares (auth/role/validate) → controllers → services → Sequelize models`. Stock decrements run inside a DB transaction with row locks to prevent overselling. Refresh-token revocation is backed by Redis and **fails closed** in production.

**Mobile** applies Clean Architecture per feature (`data / domain / presentation`), with BLoC for state and a Dio interceptor that transparently refreshes JWTs and queues concurrent requests during refresh.

---

## 🚀 DevOps & Production Infrastructure

Deployed on a single hardened VPS, but engineered like production:

| Concern | Solution |
|---------|----------|
| **Containerization** | Docker Compose — app + PostgreSQL + Redis, private network; nothing but the proxy is public |
| **TLS / Routing** | Caddy reverse proxy with **automatic** Let's Encrypt certificates & renewal |
| **CI/CD** | GitHub Actions — build-check then zero-touch SSH deploy on push to `main`; migrations gated behind a manual workflow |
| **Error tracking & APM** | Sentry — 5xx/uncaught exceptions with request context + endpoint latency/throughput |
| **Logs** | Centralized, searchable, retained in Grafana Cloud Loki (shipped by Grafana Alloy) |
| **Metrics** | Host CPU/RAM/disk/network in Grafana Cloud Prometheus |
| **Uptime** | External health-check monitor with instant alerts on API **or** DB/Redis outage |
| **Backups** | Nightly `pg_dump` with 14-day retention |
| **Security** | UFW firewall, fail2ban, key-only SSH (root login disabled), non-root deploy user, Docker log rotation |

The full, reproducible runbook lives in **[`DEPLOYMENT.md`](./DEPLOYMENT.md)**.

---

## 🏁 Getting Started

### Backend

```bash
# 1. Install dependencies
npm install

# 2. Configure environment
cp .env.example .env        # fill in DB, JWT secrets, etc.

# 3. Run migrations
npm run db:migrate
npm run db:seed             # optional: sample data (dev only)

# 4. Start (auto-reload)
npm run dev                 # → http://localhost:3000
```

Interactive API docs at **`http://localhost:3000/api-docs`** (Swagger).

### Mobile

```bash
cd bitir_yemek_mobile
flutter pub get

flutter run \
  --dart-define=API_BASE_URL=http://localhost:3000/api \
  --dart-define=MAPBOX_ACCESS_TOKEN=pk.xxx \
  --dart-define=GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com
```

### With Docker

```bash
docker compose up -d --build
docker compose exec app npm run db:migrate
```

---

## 📂 Project Structure

```
.
├── src/                      # Backend (Express)
│   ├── config/               # DB, i18n, multer, Sentry
│   ├── controllers/          # Route handlers
│   ├── middlewares/          # auth, role, validate, errorHandler
│   ├── models/               # Sequelize models & associations
│   ├── routes/               # API routes (/api/*)
│   ├── services/             # email, cache, notifications, cron, logging
│   ├── validations/          # Zod schemas
│   ├── migrations/ seeders/
│   ├── app.js  server.js
├── bitir_yemek_mobile/       # Flutter app (feature-first Clean Architecture)
│   └── lib/
│       ├── core/             # network, storage, services
│       └── features/<f>/     # data / domain / presentation
├── proxy/                    # Shared Caddy reverse proxy
├── .github/workflows/        # CI/CD (deploy, migrate)
├── docker-compose.yml  Dockerfile
└── DEPLOYMENT.md             # Production runbook
```

---

## 🔌 Key API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/auth/otp/request` · `/verify` | Passwordless email-OTP login |
| `GET`  | `/api/packages` | Browse surprise packages (geo-filtered) |
| `POST` | `/api/orders` | Reserve a package (transactional stock lock) |
| `GET`  | `/api/businesses` · `/api/maps/*` | Discover businesses / geocoding |
| `GET`  | `/api/health` | Liveness probe (DB + Redis) |

> Full schema & try-it-out available via Swagger at `/api-docs`.

---

<div align="center">

Built by **Yunus Çelik** · Node.js · Flutter · DevOps

</div>
