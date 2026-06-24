const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');
const path = require('path');
const routes = require('./routes');
const errorHandler = require('./middlewares/errorHandler');

const app = express();

app.set('trust proxy', 1);

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
    if (allowedOrigins.includes('*')) {
      return callback(null, true);
    }
    if (allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    return callback(new Error('CORS policy: origin not allowed'));
  },
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
};
app.use(cors(corsOptions));

// iyzico callback/webhook (sunucudan sunucuya) limit'e takılmamalı; aksi halde
// ödeme onayları düşebilir. retrieve OTORİTE olduğu için güvenli.
const isIyzicoServerHook = (req) => req.originalUrl.startsWith('/api/payments/iyzico/');

const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { message: 'Çok fazla istek gönderdiniz, lütfen daha sonra tekrar deneyin' },
  standardHeaders: true,
  legacyHeaders: false,
  skip: isIyzicoServerHook,
});

// Ödeme durumu poll (mobil) için cömert limit; iyzico hook'ları muaf.
const paymentsLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 600,
  message: { message: 'Çok fazla istek gönderdiniz, lütfen daha sonra tekrar deneyin' },
  standardHeaders: true,
  legacyHeaders: false,
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
});

const adminLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  message: { message: 'Çok fazla istek gönderdiniz, lütfen daha sonra tekrar deneyin' },
  standardHeaders: true,
  legacyHeaders: false,
});

app.use(generalLimiter);
app.use('/api/auth', authLimiter);
app.use('/api/business-dashboard', businessDashboardLimiter);
app.use('/api/admin', adminLimiter);
app.use('/api/payments', paymentsLimiter);

// iyzico webhook imzası için HAM gövde gerekir -> global JSON parser'dan ÖNCE,
// yalnız bu path'e scoped raw parser.
app.use('/api/payments/iyzico/webhook', express.raw({ type: '*/*', limit: '50kb' }));

app.use(express.json({ limit: '10kb' }));
app.use(express.urlencoded({ extended: true, limit: '10kb' }));

// Yüklenen görseller farklı origin'deki web istemcisinden (<img>) yüklenebilsin diye
// CORP'u cross-origin yap (helmet varsayılanı same-origin).
app.use(
  '/uploads',
  (req, res, next) => {
    res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
    next();
  },
  express.static(path.join(__dirname, '..', 'uploads'))
);

app.get('/api/health', async (req, res) => {
  const { sequelize } = require('./models');
  const cacheService = require('./services/cacheService');
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
    uptime: process.uptime(),
  });
});

app.use('/api', routes);

app.use((req, res) => {
  res.status(404).json({ message: 'Endpoint bulunamadı' });
});

app.use(errorHandler);

module.exports = app;
