const winston = require('winston');
const { redact } = require('../utils/redact');

const isProduction = process.env.NODE_ENV === 'production';

const transports = [
  // Always log to console (needed for Railway/cloud platforms)
  new winston.transports.Console({
    format: isProduction
      ? winston.format.combine(
          winston.format.timestamp(),
          winston.format.json()
        )
      : winston.format.combine(
          winston.format.colorize(),
          winston.format.simple()
        ),
  }),
];

// Only add file transports in non-production (local dev)
if (!isProduction) {
  transports.push(
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' })
  );
}

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format((info) => redact(info))(),
    winston.format.json()
  ),
  defaultMeta: { service: 'bitir-yemek' },
  transports,
});

module.exports = logger;
