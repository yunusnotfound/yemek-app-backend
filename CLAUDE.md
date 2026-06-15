# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Bitir Yemek** ("Finish the Food") is a food waste reduction platform. Restaurants and food businesses sell discounted "surprise packages" of leftover food at reduced prices. Customers browse, reserve, and pick up packages using a pickup code.

The repo contains two separate projects:
- **Backend** (root): Node.js/Express REST API
- **Mobile** (`bitir_yemek_mobile/`): Flutter app (iOS + Android)

---

## Backend (Node.js/Express)

### Commands

```bash
# Development (auto-reload)
npm run dev

# Production
npm start

# Database migrations
npm run db:migrate

# Seed with sample data (idempotent — safe to re-run)
npm run db:seed

# Run a single migration
npx sequelize-cli db:migrate --to 20240101000018-add-apple-auth-fields.js

# Undo last migration
npx sequelize-cli db:migrate:undo
```

### Environment Setup

Copy `.env.example` to `.env`. Required vars:
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` — **or** `DATABASE_URL` (Railway auto-provides)
- `JWT_SECRET`, `JWT_REFRESH_SECRET` — must be 32+ chars in production
- Optional: `RESEND_API_KEY`, `RESEND_FROM` (Resend sending domain must be verified), `GOOGLE_CLIENT_ID`, `REDIS_URL`

Additional production vars: `CORS_ORIGIN` (comma-separated browser-origin allowlist — required in prod, native apps unaffected), `APPLE_CLIENT_ID` (required for Apple Sign-In; tokens verified against this audience), `ENABLE_SWAGGER` (`/api-docs` is off in prod unless `true`).

SSL for PostgreSQL is **off by default**; set `DB_SSL=true` or include `sslmode=require` in `DATABASE_URL` to enable it.

Redis is optional for caching, but in **production** refresh-token revocation fails closed (refresh returns 401) when Redis is unavailable — run Redis in prod.

### Deployment

Targets a single Hostinger VPS (Ubuntu) — see `DEPLOYMENT.md` for the full runbook (Docker Compose or PM2). The app runs behind a **shared Caddy reverse proxy** (`proxy/`, auto-TLS via Let's Encrypt) that can front multiple apps on one box; `trust proxy` is set so the rate limiter and `req.ip` rely on `X-Forwarded-*`. The app stack (`docker-compose.yml`: app + postgres + redis) joins the external `edge` network so Caddy reaches it as `bitir-yemek-app:3000`; db/redis stay on the private `bitir-net`. `Dockerfile` provided. Migrations are run **explicitly** on deploy (`npm run db:migrate`); never run `npm run db:seed` in production (demo data with known credentials). `/api/health` is the health-check endpoint (200 up / 503 DB down). Node 20+ (`.nvmrc`, `engines`).

### Architecture

```
src/
  server.js          # Entry point — validates env, connects DB, starts cron jobs
  app.js             # Express setup — security, rate limiting, Swagger, routes
  config/
    database.js      # Sequelize instance (supports DATABASE_URL or individual vars)
    config.js        # Sequelize CLI config (used by migrations/seeders)
    i18n.js          # Turkish/English translations (default: Turkish)
    multer.js        # File upload config (images → /uploads/)
  models/index.js    # All Sequelize associations are defined here
  routes/index.js    # All routes registered under /api
  middlewares/
    auth.js          # authenticate — verifies JWT, attaches req.user
    role.js          # authorize(...roles) — checks req.user.role
    validate.js      # validate/validateQuery/validateParams — wraps Zod schemas
  validations/
    schemas.js       # All Zod schemas for request bodies/queries
  services/
    cacheService.js  # Redis get/set/del/delPattern (silent no-op if Redis down)
    socketService.js # Socket.IO — rooms: user_{id}, business_{id}
    notificationService.js # DB notifications + Socket.IO push
    emailService.js  # Resend transactional email (OTP login codes, order status, verification)
    cronService.js   # Daily jobs (Europe/Istanbul tz): 3 AM purges 30-day-old read notifications; midnight generates today's package instances from recurring templates. Assumes single instance (no distributed lock)
    geocodingService.js # Reverse geocoding
    logger.js        # Winston logger
  middlewares/errorHandler.js # Global error handler (registered last in app.js)
```

> **Routes** registered in `routes/index.js`: `auth`, `users`, `categories`, `businesses`, `packages`, `orders`, `reviews`, `favorites`, `notifications`, `coupons`, `admin`, `maps`, `business-dashboard`.

### Testing & Linting

There is **no backend test suite or linter** — no `npm test`/`npm run lint` scripts, and no ESLint/Prettier config. Don't go looking for them. Verify changes by running the server and hitting endpoints.

### User Roles

Three roles enforced via `authorize()` middleware:
- `customer` — browses and orders packages
- `business_owner` — manages their business, packages, and orders
- `admin` — full access via `/api/admin`

### Key Domain Concepts

- **SurprisePackage**: A discounted food package with `quantity`/`remainingQuantity`, `pickupDate`, `pickupStart`/`pickupEnd` window. Can be `isRecurring` with `recurringDays` (0=Sunday array of weekday ints).
- **Order**: Created with a `pickupCode`. Status flow: `pending` → `confirmed` → `picked_up` | `cancelled`. Stock is decremented with a DB transaction + row lock to prevent overselling.
- **Business**: Must be approved by admin (`isApproved`) before visible to customers.
- **Coupon**: `percentage` or `fixed` discount, with `minOrderAmount`, `maxUsage`, and expiry.

> **Note:** Real-time (Socket.IO) was removed — it was dead code (never wired into the HTTP server, no client consumers). Notifications are delivered via `notificationService` (DB rows) only. If you reintroduce realtime, attach an `http.Server` in `server.js` and add a Redis adapter only if scaling past one instance.

### Swagger API Docs

Available at `http://localhost:3000/api-docs` when running locally.

---

## Mobile (Flutter)

### Commands

```bash
cd bitir_yemek_mobile

# Install dependencies
flutter pub get

# Run (development — uses Railway backend by default)
flutter run

# Run with custom API and Mapbox token
flutter run \
  --dart-define=API_BASE_URL=https://your-api.com/api \
  --dart-define=MAPBOX_ACCESS_TOKEN=pk.xxx \
  --dart-define=GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com

# Build iOS release
flutter build ipa \
  --dart-define=API_BASE_URL=... \
  --dart-define=MAPBOX_ACCESS_TOKEN=... \
  --dart-define=GOOGLE_CLIENT_ID=...

# Analyze
flutter analyze

# Run tests
flutter test
```

### Architecture

Each feature follows Clean Architecture with three layers:

```
lib/features/<feature>/
  data/
    datasources/   # HTTP calls via DioClient
    repositories/  # Implements domain interface, maps models ↔ domain entities
    models/        # JSON serialization
  domain/
    repositories/  # Abstract interface
    entities/      # Pure Dart business objects (no framework deps)
  presentation/
    bloc/          # BLoC events/states/bloc
    pages/
    widgets/
```

Shared infrastructure in `lib/core/`:
- `network/dio_client.dart` — Dio instance with `AuthInterceptor` (auto-refreshes JWT on 401, queues concurrent requests during refresh)
- `storage/token_storage.dart` — `TokenStorage` interface. Use the `createDefaultTokenStorage()` factory, which returns `SecureTokenStorage` (encrypted: Android Keystore via `encryptedSharedPreferences`, iOS Keychain). A legacy `SharedPrefsTokenStorage` (plain, unencrypted) also exists — don't use it for tokens (one stray call remains in `package_form_page.dart`)
- `services/location_service.dart` — Geolocator wrapper

App-level constants in `lib/config/constants.dart` — all configurable values come from `--dart-define`.

### Navigation / Entry Points

`main.dart` → `SplashScreen` checks auth token + location permission, then routes to:
- `WelcomePage` — unauthenticated
- `LocationPermissionPage` — authenticated but no location
- `MainScaffold` — authenticated customer (passes lat/lng)
- `BusinessOwnerScaffold` — authenticated business_owner

### State Management

flutter_bloc throughout. Each feature's BLoC is instantiated in its page/scaffold and disposed automatically. No global BLoC providers — blocs are scoped to their feature tree.

`test/` contains only the default placeholder `widget_test.dart` — there is effectively no test coverage. Lints come from `flutter_lints` defaults (`analysis_options.yaml`).

### Key Config

- Default `baseUrl`: `https://yemek-app-backend-production.up.railway.app/api` (the Railway deployment). Override with `--dart-define=API_BASE_URL=...` for local dev.
- Mapbox and Google Sign-In are disabled/skipped gracefully if their tokens are not provided via `--dart-define`.
