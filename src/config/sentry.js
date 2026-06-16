const Sentry = require('@sentry/node');

let initialized = false;

// SENTRY_DSN tanımlı değilse devre dışı kalır (no-op).
const initSentry = () => {
  const dsn = process.env.SENTRY_DSN;
  if (!dsn) return false;

  // 0 = sadece hata; SENTRY_TRACES_SAMPLE_RATE ile performans örneklemesi açılır.
  const tracesSampleRate = process.env.SENTRY_TRACES_SAMPLE_RATE
    ? parseFloat(process.env.SENTRY_TRACES_SAMPLE_RATE)
    : 0;

  Sentry.init({
    dsn,
    environment: process.env.NODE_ENV || 'development',
    tracesSampleRate: Number.isFinite(tracesSampleRate) ? tracesSampleRate : 0,
    release: process.env.SENTRY_RELEASE || undefined,
  });

  initialized = true;
  return true;
};

const isSentryEnabled = () => initialized;

module.exports = { Sentry, initSentry, isSentryEnabled };
