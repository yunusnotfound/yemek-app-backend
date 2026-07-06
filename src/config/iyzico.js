const Iyzipay = require('iyzipay');
const logger = require('../services/logger');

// iyzico Pazaryeri (Marketplace) istemcisi — lazy singleton.
// Anahtarlar SADECE sunucuda; asla istemciye sızdırılmaz.
let client = null;

const isConfigured = () =>
  Boolean(process.env.IYZICO_API_KEY && process.env.IYZICO_SECRET_KEY);

// Ödeme ortamı: anahtar yoksa 'unconfigured', base URL sandbox içeriyorsa
// 'sandbox', aksi halde 'live'. /api/health ve boot uyarısında kullanılır.
const getMode = () => {
  if (!isConfigured()) return 'unconfigured';
  const uri = process.env.IYZICO_BASE_URL || 'https://sandbox-api.iyzipay.com';
  return /sandbox/i.test(uri) ? 'sandbox' : 'live';
};

const getClient = () => {
  if (!client && isConfigured()) {
    client = new Iyzipay({
      apiKey: process.env.IYZICO_API_KEY,
      secretKey: process.env.IYZICO_SECRET_KEY,
      uri: process.env.IYZICO_BASE_URL || 'https://sandbox-api.iyzipay.com',
    });
    logger.info(`[iyzico] istemci hazır (${process.env.IYZICO_BASE_URL || 'sandbox'})`);
  }
  return client;
};

module.exports = { Iyzipay, getClient, isConfigured, getMode };
