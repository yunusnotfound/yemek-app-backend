require("dotenv").config();

const logger = require("./services/logger");

const app = require("./app");
const { sequelize } = require("./models");
const { startNotificationCleanupJob, startRecurringPackagesJob } = require("./services/cronService");

const PORT = process.env.PORT || 3000;

// DB vars are not required if DATABASE_URL is provided (Railway)
const dbVars = process.env.DATABASE_URL
  ? []
  : ['DB_HOST', 'DB_PORT', 'DB_NAME', 'DB_USER', 'DB_PASSWORD'];
const requiredEnvVars = [...dbVars, 'JWT_SECRET', 'JWT_REFRESH_SECRET'];
const recommendedEnvVars = ['SENDGRID_API_KEY', 'SENDGRID_FROM', 'GOOGLE_CLIENT_ID'];

const validateEnv = () => {
  const missing = requiredEnvVars.filter(v => !process.env[v]);
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }
  if (process.env.NODE_ENV === 'production' && 
      (process.env.JWT_SECRET === 'your_jwt_secret_key_here' || process.env.JWT_SECRET.length < 32)) {
    throw new Error('JWT_SECRET must be a secure value (min 32 chars) in production');
  }
  // Warn about missing recommended env vars
  const missingRecommended = recommendedEnvVars.filter(v => !process.env[v]);
  if (missingRecommended.length > 0) {
    logger.warn(`Missing recommended environment variables: ${missingRecommended.join(', ')}. Some features may not work.`);
  }
};

const start = async () => {
  try {
    validateEnv();
    await sequelize.authenticate();
    logger.info("PostgreSQL bağlantısı başarılı");

    logger.info("Veritabanı bağlantısı hazır");

    // Cron job'ları başlat
    startNotificationCleanupJob();
    startRecurringPackagesJob();

    app.listen(PORT, '0.0.0.0', () => {
      logger.info(`Sunucu port ${PORT} üzerinde çalışıyor (${process.env.NODE_ENV || 'development'})`);
    });
  } catch (error) {
    logger.error("Sunucu başlatılamadı:", { error: error.message, stack: error.stack });
    console.error('FATAL:', error);
    process.exit(1);
  }
};

start();

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', { promise, reason: reason?.message || reason });
});

process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', { error: error.message, stack: error.stack });
  process.exit(1);
});
