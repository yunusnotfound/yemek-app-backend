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
- Optional: `SENDGRID_API_KEY`, `SENDGRID_FROM`, `GOOGLE_CLIENT_ID`, `REDIS_URL`

SSL for PostgreSQL is **off by default**; set `DB_SSL=true` or include `sslmode=require` in `DATABASE_URL` to enable it.

Redis is optional — the cache layer fails silently if unavailable, so the API works without it.

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
    emailService.js  # SendGrid transactional email
    cronService.js   # Runs daily at 3 AM — deletes 30-day-old read notifications
    geocodingService.js # Reverse geocoding
    logger.js        # Winston logger
```

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

### Real-time Events (Socket.IO)

```js
// Client joins rooms
socket.emit('join_user', userId)
socket.emit('join_business', businessId)

// Server emits
'stock_update'    // broadcast — { packageId, remainingQuantity }
'order_update'    // user room — order object
'new_package'     // broadcast — { businessId, package }
'notification'    // user room — notification object
```

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
- `storage/token_storage.dart` — Secure storage for access/refresh tokens and user role
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

### Key Config

- Default `baseUrl`: `https://yemek-app-backend-production.up.railway.app/api` (the Railway deployment). Override with `--dart-define=API_BASE_URL=...` for local dev.
- Mapbox and Google Sign-In are disabled/skipped gracefully if their tokens are not provided via `--dart-define`.
