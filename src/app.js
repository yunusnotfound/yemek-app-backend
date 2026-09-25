const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { ipKeyGenerator } = require('express-rate-limit');
const jwt = require('jsonwebtoken');
const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');
const path = require('path');
const routes = require('./routes');
const errorHandler = require('./middlewares/errorHandler');
const runtimeMetrics = require('./services/runtimeMetrics');

const app = express();
// Observe API responses before CORS, parsers and rate limiters can reject them.
app.use(runtimeMetrics.middleware);

// Match the actual ingress topology; never trust arbitrary forwarded hops.
app.set('trust proxy', process.env.TRUST_PROXY || 'loopback, linklocal, uniquelocal');

const isProduction = process.env.NODE_ENV === 'production';

const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Bitir Yemek API',
      version: '1.0.0',
      description: 'Bitir Yemek - Yemek israfını önleme platformu API dokümantasyonu',
      contact: {
        name: 'Bitir Yemek',
        email: 'info@bitiryemek.com',
      },
    },
    servers: [
      {
        url: process.env.API_URL || 'http://localhost:3000/api',
        description: 'Development Server',
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
    },
    security: [
      {
        bearerAuth: [],
      },
    ],
  },
  apis: ['./src/routes/*.js', './src/controllers/*.js'],
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);

if (!isProduction || process.env.ENABLE_SWAGGER === 'true') {
  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
    explorer: true,
    customCss: '.swagger-ui .topbar { display: none }',
    customSiteTitle: 'Bitir Yemek API Docs',
  }));
}

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
  crossOriginEmbedderPolicy: false,
}));

// Public images do not consume API/auth rate limits. Serve them before the
// credentialed API CORS middleware so a CDN can share one response across origins.
const uploadsDirectory = path.join(__dirname, '..', 'uploads');
app.use(
  '/uploads',
  (req, res, next) => {
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Content-Security-Policy', "default-src 'none'; sandbox");
    next();
  },
  cors({ origin: '*', methods: ['GET', 'HEAD'], credentials: false }),
  express.static(uploadsDirectory, {
    fallthrough: false,
    index: false,
    redirect: false,
    setHeaders: (res, filePath) => {
      const relativePath = path.relative(uploadsDirectory, filePath);
      // Uploads receive a new UUID on every write; replacements have new URLs.
      const isImmutableUpload = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png|webp)$/i.test(relativePath);
      const isVersionedCatalog = /^demo-catalog-v\d+\/[\w-]+\.(jpg|png|webp)$/i.test(relativePath);
      const cacheControl = isImmutableUpload
        ? 'public, max-age=31536000, immutable'
        : `public, max-age=${isVersionedCatalog ? 604800 : 86400}`;
      res.setHeader('Cache-Control', cacheControl);
    },
  }),
  (err, req, res, next) => {
    // Missing files and invalid ranges must not inherit a successful image TTL.
    res.setHeader('Cache-Control', 'no-store');
    // Static-file ENOENT messages contain the server's absolute storage path.
    if (err.statusCode === 404) {
      return res.status(404).json({ success: false, message: 'Görsel bulunamadı' });
    }
    next(err);
  }
);

// Native uygulamalar Origin göndermez; Origin'siz istekler her zaman izinli.
// CORS_ORIGIN, tarayıcı istemcileri için virgülle ayrılmış izin listesidir.
const allowedOrigins = (process.env.CORS_ORIGIN || '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

const corsOptions = {
  origin: (origin, callback) => {
    if (!origin) {
      return callback(null, true);
    }
    if (!isProduction && allowedOrigins.length === 0) {
      return callback(null, true);
    }
    if (!isProduction && allowedOrigins.includes('*')) {
      return callback(null, true);
    }
    if (allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    return callback(Object.assign(new Error('CORS policy: origin not allowed'), { statusCode: 403 }));
  },
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
};
// iyzico callback/webhook (sunucudan sunucuya) limit'e ve CORS'a takılmamalı;
// aksi halde ödeme onayları düşebilir. retrieve OTORİTE olduğu için güvenli.
const isIyzicoServerHook = (req) => req.originalUrl.startsWith('/api/payments/iyzico/');

// CORS, iyzico callback'lerine uygulanmaz: banka 3DS sayfası ve iyzico formu
// callback'e tarayıcı form POST'u ile döner ve Origin taşır (WebView'da "null").
// Bu uçlar JWT'siz + idempotent, gerçek doğrulama iyzico retrieve — CORS'un
// koruyacağı bir şey yok; reddetmek ödeme onayını düşürür.
const corsMiddleware = cors(corsOptions);
app.use((req, res, next) => (isIyzicoServerHook(req) ? next() : corsMiddleware(req, res, next)));

// Giriş yapmış isteklerde limiti kullanıcı bazlı anahtarla (mobil operatör
// CGNAT'ında çok sayıda kullanıcı tek public IP paylaştığı için IP bazlı limit
// haksız 429 üretiyordu). Token yoksa/geçersizse IP'ye düş (IPv6-güvenli).
const userOrIpKey = (req, res) => {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    try {
      const decoded = jwt.verify(authHeader.split(' ')[1], process.env.JWT_SECRET, { algorithms: ['HS256'] });
      if (decoded && decoded.id) return `user:${decoded.id}`;
    } catch (_) {
      // süresi dolmuş / geçersiz token → IP'ye düş
    }
  }
  return ipKeyGenerator(req.ip);
};

// Foreground catalog refresh can make 2–3 reads every 15 seconds. Give only
// these read routes their own budget; writes and unrelated APIs retain theirs.
const catalogPath = /^\/api\/(?:(?:businesses|packages)(?:\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})?|maps\/nearby|favorites)\/?$/i;
const isCatalogRead = (req) => req.method === 'GET' && catalogPath.test(req.path);

const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { message: 'Çok fazla istek gönderdiniz, lütfen daha sonra tekrar deneyin' },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: userOrIpKey,
  skip: req => isCatalogRead(req) || isIyzicoServerHook(req) || /^\/api\/(auth|cards|business-dashboard|admin|payments)(\/|$)/.test(req.originalUrl),
});

const catalogLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  message: { message: 'Çok fazla istek gönderdiniz, lütfen daha sonra tekrar deneyin' },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: userOrIpKey,
  skip: req => !isCatalogRead(req),
});

// Ödeme durumu poll (mobil) için cömert limit; iyzico hook'ları muaf.
const paymentsLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 600,
  message: { message: 'Çok fazla istek gönderdiniz, lütfen daha sonra tekrar deneyin' },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: userOrIpKey,
  skip: isIyzicoServerHook,
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  message: { message: 'Çok fazla giriş denemesi, lütfen 15 dakika sonra tekrar deneyin' },
  standardHeaders: true,
  legacyHeaders: false,
});

const businessDashboardLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 200,
  message: { message: 'Çok fazla istek gönderdiniz, lütfen daha sonra tekrar deneyin' },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: userOrIpKey,
});

const adminLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  message: { message: 'Çok fazla istek gönderdiniz, lütfen daha sonra tekrar deneyin' },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: userOrIpKey,
});

// Kart kaydetme uçları için sıkı limit (BIN-testing / kart doğrulama saldırılarına karşı).
const cardsLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 20,
  message: { message: 'Çok fazla kart işlemi, lütfen daha sonra tekrar deneyin' },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: userOrIpKey,
});

// Rate limiting'i test ortamında devre dışı bırak — testler auth uçlarını yoğun
// kullandığından global/auth limitleri spurious 429 üretirdi.
if (process.env.NODE_ENV !== 'test') {
  app.use(generalLimiter);
  app.use(catalogLimiter);
  app.use('/api/auth', authLimiter);
  app.use('/api/cards', cardsLimiter);
  app.use('/api/business-dashboard', businessDashboardLimiter);
  app.use('/api/admin', adminLimiter);
  app.use('/api/payments', paymentsLimiter);
  app.use('/api/payments/iyzico', rateLimit({ windowMs: 60 * 1000, max: 300,
    standardHeaders: true, legacyHeaders: false,
    message: { message: 'Çok fazla ödeme bildirimi' } }));
}

// iyzico webhook imzası için HAM gövde gerekir -> global JSON parser'dan ÖNCE,
// yalnız bu path'e scoped raw parser.
app.use('/api/payments/iyzico/webhook', express.raw({ type: '*/*', limit: '50kb' }));

app.use(express.json({ limit: '10kb' }));
app.use(express.urlencoded({ extended: true, limit: '10kb' }));

app.get('/api/health', async (req, res) => {
  const { sequelize } = require('./models');
  const cacheService = require('./services/cacheService');
  const iyzico = require('./config/iyzico');
  const isProduction = process.env.NODE_ENV === 'production';

  let database = 'connected';
  try {
    await sequelize.authenticate();
  } catch (error) {
    database = 'disconnected';
  }

  const redis = (await cacheService.ping()) ? 'connected' : 'disconnected';

  // Redis yalnızca production'da health'i etkiler (fail-closed refresh-token politikası).
  const healthy =
    database === 'connected' && (redis === 'connected' || !isProduction);

  res.status(healthy ? 200 : 503).json({
    status: healthy ? 'ok' : 'unhealthy',
    timestamp: new Date().toISOString(),
    database,
    redis,
    // 'live' | 'sandbox' | 'unconfigured' — canlı geçişte doğrulama için (health'i etkilemez).
    iyzicoMode: iyzico.getMode(),
    uptime: process.uptime(),
  });
});

app.use('/api', routes);

app.use((req, res) => {
  res.status(404).json({ message: 'Endpoint bulunamadı' });
});

app.use(errorHandler);

module.exports = app;
