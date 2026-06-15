# Bitir Yemek — Production Readiness Raporu

**İlk denetim:** 2026-06-15 · **Güncelleme (düzeltmeler uygulandı):** 2026-06-15
**Hedef ortam:** Tek Hostinger VPS (Ubuntu, KVM 2) — app + PostgreSQL + Redis, önde **paylaşımlı Caddy** reverse proxy (otomatik Let's Encrypt TLS, çoklu-app). Yatay ölçekleme YOK (tek instance).
**Yöntem:** Çok-ajanlı denetim → kesişmeyen dosya sahipliğiyle 6 paralel ajanla düzeltme → entegrasyon & doğrulama.

---

## Durum Özeti

| Alan | İlk durum | Şimdiki durum |
|------|-----------|----------------|
| Güvenlik (CORS, Apple aud, reset token, refresh) | ❌ Kritik açıklar | ✅ Düzeltildi |
| Veri bütünlüğü (pickupCode, state machine, index) | ❌ Bloker | ✅ Düzeltildi |
| Dağıtım & güvenilirlik (graceful shutdown, config) | ❌ Yok | ✅ Eklendi (VPS) |
| Gözlemlenebilirlik (error suppression, timeout) | ❌ | ⚠️ Kısmi (Sentry/morgan opsiyonel kaldı) |
| Mobil yayın (ATS, signing, error handling) | ❌ Bloker | ✅ Kod tarafı bitti — keystore kullanıcıda |
| Dead code (Socket.IO) | ❌ | ✅ Kaldırıldı |

**Sonuç:** Tüm P0 blokerler ve P1 maddelerinin büyük çoğunluğu **kod tarafında kapatıldı ve doğrulandı** (`node --check` tüm dosyalarda geçti, `app.js` + cron + helpers + migration temiz require ediliyor, `flutter analyze` yeni hata yok). Canlıya almadan önce yalnızca **kullanıcı aksiyonu gereken** maddeler kaldı (alt bölüme bakın): Android release keystore, DNS+TLS, prod secret'ları, ve build sonrası R8 doğrulaması.

---

## ✅ Bu Turda Yapılanlar

### Güvenlik — Backend (`authController.js`, `app.js`, `server.js`, `errorHandler.js`, `database.js`)
- **CORS kilitlendi**: `CORS_ORIGIN` artık virgülle ayrılmış allowlist; prod'da `*` yok, Origin'siz native mobil istekleri korunuyor. `app.js`.
- **trust proxy = 1** eklendi (Caddy proxy arkası) → rate limiter & `req.ip` doğru çalışıyor.
- **Apple Sign-In `aud` doğrulaması**: `audience: APPLE_CLIENT_ID` pinlendi; env yoksa açık hata. `authController.js:354,382`.
- **Parola sıfırlama sertleştirildi**: `Math.random` → `crypto.randomInt`, kod artık SHA-256 hash olarak saklanıyor, expiry 1 saat → 15 dk. Email-verification token'ı da hash'leniyor. `authController.js:227`.
- **JWT access token expiry fallback**: `JWT_EXPIRES_IN || '15m'`, refresh `|| '7d'` → token artık her zaman expire oluyor.
- **Refresh-token iptali prod'da fail-closed**: Redis yoksa prod'da refresh 401 döner (sessizce atlamak yerine).
- **500 hata mesajı gizleme**: prod'da generic 'Sunucu hatası', iç mesaj sızmıyor (loglama korunuyor). `errorHandler.js`.
- **Swagger prod'da kapalı** (`ENABLE_SWAGGER=true` hariç). `app.js:56`.

### Veri Bütünlüğü & Performans — Backend (`helpers.js`, `orderController.js`, `businessDashboardController.js`, `Order.js`, yeni migration)
- **pickupCode yeniden tasarlandı**: 6 haneli `crypto.randomInt`; benzersizlik yalnızca aktif siparişlere (`pending`/`confirmed`) scope'landı → havuz tükenmez. `helpers.js`.
- **Partial unique index** `Orders(pickupCode) WHERE status IN (pending,confirmed)` + order create'te unique-violation retry → TOCTOU yarışı kapandı.
- **pickupCode kolonu `VARCHAR(4)`→`VARCHAR(6)` genişletildi** (migration'da `changeColumn`) — *entegrasyonda yakalanan kritik eksik; olmasa 6 haneli kodlar tüm sipariş oluşturmayı kırardı.*
- **Sipariş durum makinesi**: `updateStatus` artık geçerli geçişleri zorluyor; `cancelled`'a geçişte stok transaction içinde **iade ediliyor** (önceden sessizce kayboluyordu).
- **Cache invalidation**: stok değişiminde (order create/cancel) `packages:list:*` temizleniyor.
- **Eksik index'ler eklendi**: `SurprisePackages(pickupDate)`, `(isActive,pickupDate)`, `Businesses(city)`, `(district)`, `(latitude,longitude)`, `Orders(couponId)`, `Reviews(orderId)`.

### Paket / Cron / KVKK — Backend (`packageController.js`, `cronService.js`, `userController.js`)
- **Geo sorgusu sınırlandı**: SQL bounding-box ön-filtresi + 500 satır cap (önceden tüm tabloyu belleğe çekiyordu); cache key koordinatları 3 ondalığa yuvarlıyor → gerçek cache hit.
- **Cron timezone**: her iki job `Europe/Istanbul`; gün hesabı Istanbul-local → recurring paketler doğru günde.
- **KVKK uyumlu hesap silme** (tek transaction): aktif siparişler iptal + **stok iadesi**, PII anonimleştirme (ad/email/telefon/token'lar temizleniyor), `business_owner` işletmeleri pasifleştiriliyor.

### Dağıtım — Hostinger VPS (yeni dosyalar)
- `Dockerfile` (multi-stage, Node 20-alpine, non-root, HEALTHCHECK), `.dockerignore`, `docker-compose.yml` (app+postgres+redis, named volume'lar, healthcheck'ler; app paylaşımlı `edge` ağında).
- **`proxy/`** — paylaşımlı Caddy reverse proxy (`docker-compose.yml` + `Caddyfile`): otomatik Let's Encrypt TLS, domain routing, güvenlik header'ları, çoklu-app desteği (yeni app = Caddyfile'a tek blok).
- `ecosystem.config.js` (PM2 alternatifi, tek instance).
- `.nvmrc` (20), `package.json` `engines` + temizlenmiş script'ler (no-op postinstall kaldırıldı).
- **`DEPLOYMENT.md`**: sıfırdan VPS runbook — sunucu sertleştirme (ufw/fail2ban/SSH), Docker Compose & PM2 yolları, DNS, `openssl rand` ile secret üretimi, certbot/TLS, **explicit migration**, "asla `db:seed` çalıştırma" uyarısı, pg_dump yedekleme, env-var tablosu.

### Mobil (`bitir_yemek_mobile/`)
- **API URL'i HTTPS prod default'una geri alındı** (localhost http kaldırıldı); VPS domain'i `--dart-define` ile override notu eklendi.
- **iOS ATS açığı kapatıldı** (`NSAllowsArbitraryLoads` silindi); Android `usesCleartextTraffic="false"`.
- **Global hata yakalama**: `runZonedGuarded` + `FlutterError.onError` + `BlocObserver`; `SplashScreen._checkAuth` try/catch ile korundu (sonsuz splash riski giderildi).
- **Token-refresh null-safe** parse (blind `as String` cast'i kaldırıldı).
- **Repo/BLoC hata sarmalama** tutarlı hale getirildi (orders/favorites/business_owner); `MapBloc` sessiz hata yutması düzeltildi.
- **Token storage bug'ı**: `package_form_page` artık `SecureTokenStorage` kullanıyor; ölü `SharedPrefsTokenStorage` sınıfı kaldırıldı.
- **Release signing config** (`key.properties`'ten okuyor) + R8 minify/shrink + `proguard-rules.pro`; `namespace` `com.example.*`→`com.bitiryemek.mobile` (MainActivity taşındı); iOS `MARKETING_VERSION` 1.0.0.

### Dead Code
- **Socket.IO tamamen kaldırıldı**: `src/services/socketService.js` silindi, `socket.io` bağımlılığı `npm uninstall` edildi. Hiçbir yerde kullanılmıyordu (ne backend ne mobil). CLAUDE.md'deki real-time bölümü güncellendi.

### Doğrulama
- Tüm değiştirilen backend dosyalarında `node --check` ✅; `app.js` + `cronService` + `helpers` + yeni migration temiz require ✅; `npm install` socket.io kaldırma sonrası tutarlı ✅.
- `flutter analyze`: yalnızca dokunulmayan dosyalarda önceden var olan 19 `info` uyarısı; düzenlenen dosyalarda **yeni hata yok** ✅.

---

## 🔧 Kalan — Kullanıcı Aksiyonu Gerekiyor (canlı öncesi)

| # | Madde | Nasıl |
|---|-------|-------|
| 1 | **Android release keystore** | `keytool -genkey -v -keystore ~/bitiryemek-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias bitiryemek` → `android/key.properties` doldur (örnek: `key.properties.example`). Keystore'u commit etme. |
| 2 | **iOS dağıtım sertifikası** | Xcode → Runner target → Signing & Capabilities'te Apple distribution cert + provisioning profile. |
| 3 | **Prod secret'ları** | `.env`'i `.env.example`'dan oluştur; `JWT_SECRET`/`JWT_REFRESH_SECRET` = `openssl rand -hex 32`; `APPLE_CLIENT_ID`, `GOOGLE_CLIENT_ID`, `CORS_ORIGIN` ayarla. |
| 4 | **DNS + TLS** | `api.<domain>` A kaydı → VPS IP; `proxy/Caddyfile`'da `email` + domain'i gir; `docker network create edge` (bir kez). TLS otomatik (certbot yok). DEPLOYMENT.md. |
| 5 | **Migration çalıştır** | VPS'te `npm run db:migrate` (yeni 21 numaralı migration pickupCode kolonunu genişletir + index'leri ekler). **`db:seed` ASLA prod'da.** |
| 6 | **Mobil prod build doğrula** | R8 artık açık — `flutter build appbundle`/`ipa` sonrası Mapbox & Google Sign-In'i test et; eksik sınıf olursa `proguard-rules.pro`'yu genişlet. Build'lerde `--dart-define=API_BASE_URL=https://<vps-domain>/api` geç. |

## ⏭️ Ertelenen / Opsiyonel (P2 — yayın sonrası)
- **Error tracking (Sentry) + request log (morgan)**: eklenmedi (yeni bağımlılık). Mobilde `_reportError` içinde TODO bırakıldı. Önerilir.
- **Parola sıfırlama hesap-bazlı deneme sayacı**: yeni DB kolonu gerektirdiği için ertelendi; şimdilik 15 dk expiry + global rate-limit ile azaltıldı.
- **Para hesabını integer-cents'e taşıma**: saklama zaten DECIMAL (güvenli); ara hesap float — düşük öncelik.
- **Review anonimleştirme**: silinen kullanıcının review'ları duruyor (ilişki anonimleştirilmiş kullanıcıyı gösteriyor, ham PII sızmıyor) — tam ayrıştırma istenirse ayrı karar/migration.
- **Coupon per-user kullanım limiti**: iş kuralı kararı bekliyor.

---

## ✅ Zaten Sağlam Olanlar (değişmedi)
Yetkilendirme/ownership kontrolleri · atomik & transactional stok düşümü · hassas alanların API çıktısından çıkarılması · tüm mutasyonlarda Zod validation · register'da admin escalation koruması · mobil şifreli token storage (`SecureTokenStorage`) · boot'ta fail-fast env doğrulama · idempotent seeder'lar · koşullu SSL.
