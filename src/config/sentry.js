const Sentry = require('@sentry/node');

let initialized = false;

// Initializes Sentry only when SENTRY_DSN is set. With no DSN this is a no-op,
// so local dev and any environment without the var keep their current behaviour.
const initSentry = () => {
  const dsn = process.env.SENTRY_DSN;
  if (!dsn) return false;

  // Performance/APM sampling. 0 (default) = errors only. Set
  // SENTRY_TRACES_SAMPLE_RATE (e.g. 0.2 = 20% of requests) to capture
  // endpoint latency/throughput. Express + HTTP are auto-instrumented because
  // initSentry() runs before app.js (and thus express) is required.
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
