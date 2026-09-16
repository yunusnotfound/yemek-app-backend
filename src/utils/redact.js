const secretKey = /password|token|secret|authorization|cookie|card|cvc|cvv|iban|identitynumber|email|phone|gsm/i;
const redactText = (text) => String(text)
  .replace(/Bearer\s+\S+/gi, 'Bearer [REDACTED]')
  .replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, '[TOKEN]')
  .replace(/\b\d{11,19}\b/g, '[REDACTED]');

const redact = (value, seen = new WeakSet()) => {
  if (typeof value === 'string') return redactText(value);
  if (!value || typeof value !== 'object') return value;
  if (seen.has(value)) return '[Circular]';
  seen.add(value);
  if (Array.isArray(value)) return value.map(item => redact(item, seen));
  const result = {};
  for (const key of Reflect.ownKeys(value)) {
    result[key] = typeof key === 'string' && secretKey.test(key) ? '[REDACTED]' : redact(value[key], seen);
  }
  return result;
};

module.exports = { redact, redactText };
