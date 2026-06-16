require("dotenv").config();

const logger = require("./services/logger");
const { Sentry, initSentry, isSentryEnabled } = require("./config/sentry");

if (initSentry()) {
  logger.info("Sentry hata takibi etkin");
}

const app = require("./app");
const { sequelize } = require("./models");
const { startNotificationCleanupJob, startRecurringPackagesJob } = require("./services/cronService");

const PORT = process.env.PORT || 3000;

const dbVars = process.env.DATABASE_URL
  ? []
  : ['DB_HOST', 'DB_PORT', 'DB_NAME', 'DB_USER', 'DB_PASSWORD'];
const requiredEnvVars = [...dbVars, 'JWT_SECRET', 'JWT_REFRESH_SECRET'];
const recommendedEnvVars = ['RESEND_API_KEY', 'RESEND_FROM', 'GOOGLE_CLIENT_ID'];

const validateEnv = () => {
  const missing = requiredEnvVars.filter(v => !process.env[v]);
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }
  if (process.env.NODE_ENV === 'production' && 
      (process.env.JWT_SECRET === 'your_jwt_secret_key_here' || process.env.JWT_SECRET.length < 32)) {
    throw new Error('JWT_SECRET must be a secure value (min 32 chars) in production');
  }
  const missingRecommended = recommendedEnvVars.filter(v => !process.env[v]);
  if (missingRecommended.length > 0) {
    logger.warn(`Missing recommended environment variables: ${missingRecommended.join(', ')}. Some features may not work.`);
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
    } finally {
      clearTimeout(forceExit);
      process.exit(0);
    }
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

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', { promise, reason: reason?.message || reason });
  if (isSentryEnabled()) Sentry.captureException(reason);
  shutdown('unhandledRejection');
});

process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', { error: error.message, stack: error.stack });
  if (isSentryEnabled()) Sentry.captureException(error);
  shutdown('uncaughtException');
});
