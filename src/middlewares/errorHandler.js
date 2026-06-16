const logger = require('../services/logger');
const { Sentry, isSentryEnabled } = require('../config/sentry');

const errorHandler = (err, req, res, next) => {
  logger.error('Request error', {
    error: err.message,
    stack: err.stack,
    statusCode: err.statusCode || 500,
    path: req.path,
    method: req.method,
  });

  // Report unexpected (5xx) errors to Sentry with request context. Intentional
  // 4xx responses (validation, conflicts, auth) are deliberate, not noise.
  if (isSentryEnabled() && (err.statusCode || 500) >= 500) {
    Sentry.withScope((scope) => {
      scope.setTag('method', req.method);
      scope.setTag('path', req.path);
      if (req.user?.id) scope.setUser({ id: req.user.id });
      Sentry.captureException(err);
    });
  }

  if (err.name === 'SequelizeValidationError') {
    const messages = err.errors.map((e) => e.message);
    return res.status(400).json({
      success: false,
      message: 'Doğrulama hatası',
      errors: messages,
    });
  }

  if (err.name === 'SequelizeUniqueConstraintError') {
    return res.status(409).json({
      success: false,
      message: 'Bu kayıt zaten mevcut',
    });
  }

  const statusCode = err.statusCode || 500;

  // Production'da 500'lük hatalarda ham mesajı sızdırma; genel mesaj döndür.
  // 4xx hataları (validation vb.) bilerek mesaj döndürdüğü için korunur.
  const isProduction = process.env.NODE_ENV === 'production';
  const message =
    isProduction && statusCode >= 500
      ? 'Sunucu hatası'
      : err.message || 'Sunucu hatası';

  res.status(statusCode).json({
    success: false,
    message,
  });
};

module.exports = errorHandler;
