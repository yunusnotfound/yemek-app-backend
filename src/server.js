require("dotenv").config();

const logger = require("./services/logger");
const { Sentry, initSentry, isSentryEnabled } = require("./config/sentry");
const iyzico = require("./config/iyzico");

if (initSentry()) {
  logger.info("Sentry hata takibi etkin");
}

const app = require("./app");
const { sequelize } = require("./models");
const cacheService = require("./services/cacheService");
const {
  startNotificationCleanupJob,
  startRecurringPackagesJob,
  startPaymentReaperJob,
  startApprovalRetryJob,
} = require("./services/cronService");

const PORT = process.env.PORT || 3000;

const dbVars = process.env.DATABASE_URL
  ? []
  : ['DB_HOST', 'DB_PORT', 'DB_NAME', 'DB_USER', 'DB_PASSWORD'];
const requiredEnvVars = [...dbVars, 'JWT_SECRET', 'JWT_REFRESH_SECRET'];
const recommendedEnvVars = [
  'RESEND_API_KEY', 'RESEND_FROM', 'GOOGLE_CLIENT_ID',
  // iyzico ödeme — eksikse ödemeler çalışmaz (uyarı, fatal değil).
  'IYZICO_API_KEY', 'IYZICO_SECRET_KEY', 'IYZICO_CALLBACK_URL',
  // Apple Sign-In token audience'ı ve tarayıcı web istemcileri için CORS allowlist'i.
  'APPLE_CLIENT_ID', 'CORS_ORIGIN',
];

// Placeholder ya da yeterince güçlü olmayan secret'ı yakalar.
const isWeakSecret = (v) => !v || v.length < 32 || /your_jwt_.*_here/.test(v);

const validateEnv = () => {
  const missing = requiredEnvVars.filter(v => !process.env[v]);
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }
  const isProd = process.env.NODE_ENV === 'production';
  if (isProd && isWeakSecret(process.env.JWT_SECRET)) {
    throw new Error('JWT_SECRET must be a secure value (min 32 chars) in production');
  }
  if (isProd && isWeakSecret(process.env.JWT_REFRESH_SECRET)) {
    throw new Error('JWT_REFRESH_SECRET must be a secure value (min 32 chars) in production');
  }
  const missingRecommended = recommendedEnvVars.filter(v => !process.env[v]);
  if (missingRecommended.length > 0) {
    logger.warn(`Missing recommended environment variables: ${missingRecommended.join(', ')}. Some features may not work.`);
  }
  // E-posta doğrulama linkleri bu API'nin public origin'ine gider; ikisi de yoksa
  // linkler localhost'a düşer (ölü link).
  if (isProd && !process.env.APP_URL && !process.env.PUBLIC_API_URL) {
    logger.warn("APP_URL/PUBLIC_API_URL üretimde ayarlı değil — e-posta doğrulama linkleri localhost'a düşer.");
  }
  // iyzico ödeme ortamı uyarıları (yalnız production'da yüksek görünürlük) —
  // canlıya sandbox/test ayarlarıyla çıkmayı önlemek için fatal DEĞİL, belirgin uyarı.
  if (isProd) {
    const mode = iyzico.getMode();
    if (mode !== 'live') {
      logger.warn(`⚠️  iyzico ödeme ortamı '${mode}' — CANLI ödeme için 'live' olmalı. IYZICO_BASE_URL=https://api.iyzipay.com + gerçek anahtarları ayarlayın.`);
    }
    if (process.env.IYZICO_TEST_DIRECT_CHARGE === 'true') {
      logger.warn('⚠️  IYZICO_TEST_DIRECT_CHARGE=true (komisyon split/approval YOK) — canlıya çıkmadan kaldırın.');
    }
  }
};

let server;
let isShuttingDown = false;

const shutdown = (signal) => {
  if (isShuttingDown) return;
  isShuttingDown = true;
  logger.info(`${signal} alındı, sunucu düzgün şekilde kapatılıyor...`);

  // Asılı kalırsa zorla çık
  const forceExit = setTimeout(() => {
    logger.error('Düzgün kapanış zaman aşımına uğradı, zorla çıkılıyor');
    process.exit(1);
  }, 10000);
  forceExit.unref();

  const closeDbAndExit = async () => {
    try {
      await sequelize.close();
      logger.info('Veritabanı bağlantısı kapatıldı');
    } catch (error) {
      logger.error('Veritabanı kapatılırken hata:', { error: error.message });
    }
    try {
      await cacheService.quit();
      logger.info('Redis bağlantısı kapatıldı');
    } catch (error) {
      logger.error('Redis kapatılırken hata:', { error: error.message });
    }
    clearTimeout(forceExit);
    process.exit(0);
  };

  if (server) {
    server.close(() => {
      logger.info('HTTP sunucusu yeni bağlantıları kabul etmeyi durdurdu');
      closeDbAndExit();
    });
  } else {
    closeDbAndExit();
  }
};

const start = async () => {
  try {
    validateEnv();
    await sequelize.authenticate();
    logger.info("PostgreSQL bağlantısı başarılı");

    logger.info("Veritabanı bağlantısı hazır");

    startNotificationCleanupJob();
    startRecurringPackagesJob();
    startPaymentReaperJob();
    startApprovalRetryJob();

    server = app.listen(PORT, '0.0.0.0', () => {
      logger.info(`Sunucu port ${PORT} üzerinde çalışıyor (${process.env.NODE_ENV || 'development'})`);
    });
  } catch (error) {
    logger.error("Sunucu başlatılamadı:", { error: error.message, stack: error.stack });
    console.error('FATAL:', error);
    process.exit(1);
  }
};

start();

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

process.on('unhandledRejection', (reason) => {
  // Tek instance'ta tüm süreci kapatmak yerine yalnız raporla — tek bir kaçak
  // promise rejection tüm kullanıcılar için kesintiye yol açmasın. Gerçek fatal
  // durum (uncaughtException) aşağıda hâlâ düzgün kapanışı tetikler.
  logger.error('Unhandled Rejection:', { reason: reason?.message || reason, stack: reason?.stack });
  if (isSentryEnabled()) Sentry.captureException(reason);
});

process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', { error: error.message, stack: error.stack });
  if (isSentryEnabled()) Sentry.captureException(error);
  shutdown('uncaughtException');
});
