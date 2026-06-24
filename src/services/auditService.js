const { AdminAuditLog } = require('../models');
const logger = require('./logger');

// Hassas anahtarları metadata'dan maskele (asla loglanmaz).
const SENSITIVE = /(password|token|iban|identitynumber|taxnumber|secret|cardnumber|cvc|cvv|apikey)/i;

const sanitize = (value) => {
  if (!value || typeof value !== 'object') return value;
  if (Array.isArray(value)) return value.map(sanitize);
  const out = {};
  for (const [k, v] of Object.entries(value)) {
    if (SENSITIVE.test(k)) {
      out[k] = '***';
    } else if (v && typeof v === 'object') {
      out[k] = sanitize(v);
    } else {
      out[k] = v;
    }
  }
  return out;
};

/**
 * Mutasyonel admin işlemini denetim kaydına yaz. ASLA throw etmez (ana işlemi bloklamaz).
 * @param {{ req: object, action: string, targetType?: string, targetId?: string|number, metadata?: object }}
 */
const record = async ({ req, action, targetType, targetId, metadata }) => {
  try {
    await AdminAuditLog.create({
      adminId: req.user.id,
      action,
      targetType: targetType || null,
      targetId: targetId != null ? String(targetId) : null,
      metadata: metadata ? sanitize(metadata) : null,
      ip: req.ip,
    });
  } catch (e) {
    logger.error(`[audit] kayıt başarısız (${action}): ${e.message}`);
  }
};

module.exports = { record, sanitize };
