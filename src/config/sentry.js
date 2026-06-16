const Sentry = require('@sentry/node');

let initialized = false;

// Initializes Sentry only when SENTRY_DSN is set. With no DSN this is a no-op,
// so local dev and any environment without the var keep their current behaviour.
const initSentry = () => {
  const dsn = process.env.SENTRY_DSN;
  if (!dsn) return false;

  Sentry.init({
    dsn,
    environment: process.env.NODE_ENV || 'development',
    // Error tracking only — performance tracing off to stay within the free quota.
    tracesSampleRate: 0,
    release: process.env.SENTRY_RELEASE || undefined,
  });

  initialized = true;
  return true;
};

const isSentryEnabled = () => initialized;

module.exports = { Sentry, initSentry, isSentryEnabled };
