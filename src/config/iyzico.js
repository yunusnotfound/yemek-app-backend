const Iyzipay = require('iyzipay');
const logger = require('../services/logger');

// iyzico Pazaryeri (Marketplace) istemcisi — lazy singleton.
// Anahtarlar SADECE sunucuda; asla istemciye sızdırılmaz.
let client = null;

const isConfigured = () =>
  Boolean(process.env.IYZICO_API_KEY && process.env.IYZICO_SECRET_KEY);

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

module.exports = { Iyzipay, getClient, isConfigured };
