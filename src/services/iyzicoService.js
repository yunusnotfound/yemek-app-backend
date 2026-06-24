const crypto = require('crypto');
const { Iyzipay, getClient, isConfigured } = require('../config/iyzico');
const logger = require('./logger');

// Platform komisyon oranı (0.10 = %10). subMerchantPrice = finalPrice * (1 - rate).
const COMMISSION_RATE = (() => {
  const r = parseFloat(process.env.PLATFORM_COMMISSION_RATE);
  return Number.isFinite(r) && r >= 0 && r < 1 ? r : 0.1;
})();

const COMMISSION_RATE_VALUE = COMMISSION_RATE;

// iyzico tutarları string, 2 ondalık. price === sum(basketItems.price) olmalı.
const formatPrice = (n) => Number(n || 0).toFixed(2);

// İşletmeye ayrılan tutar (komisyon düşülmüş). En az 0.01 (iyzico 0 kabul etmez).
const calcSubMerchantPrice = (finalPrice) => {
  const net = Number(finalPrice) * (1 - COMMISSION_RATE);
  return formatPrice(Math.max(0.01, Math.round(net * 100) / 100));
};

const splitName = (fullName = '') => {
  const parts = String(fullName).trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return { name: 'Bitir', surname: 'Müşteri' };
  if (parts.length === 1) return { name: parts[0], surname: parts[0] };
  return { name: parts.slice(0, -1).join(' '), surname: parts[parts.length - 1] };
};

// iyzico SDK callback'lerini Promise'e sarar. result.status'ı kontrol etmek çağırana kalır.
const call = (resource, method, request) =>
  new Promise((resolve, reject) => {
    const client = getClient();
    if (!client) return reject(new Error('iyzico yapılandırılmamış (IYZICO_API_KEY eksik)'));
    client[resource][method](request, (err, result) => {
      if (err) return reject(err);
      resolve(result);
    });
  });

/**
 * Pazaryeri Checkout Form başlat. basketItem alt üye işyeri (subMerchantKey/Price) taşır.
 * @returns {{ token, checkoutFormContent, paymentPageUrl, conversationId }}
 */
const initializeCheckoutForm = async ({ order, user, business, pkg, categoryName, ip }) => {
  const { name, surname } = splitName(user.name);
  const price = formatPrice(order.finalPrice);

  // Pazaryeri kalemi: yalnız submerchant varsa kırılım (subMerchantKey/Price) gönder.
  // submerchant yoksa düz tahsilat (test modu) — kalem submerchant alanları taşımaz.
  const basketItem = {
    id: pkg.id,
    name: pkg.title,
    category1: categoryName || 'Gıda',
    itemType: Iyzipay.BASKET_ITEM_TYPE.PHYSICAL,
    price,
  };
  if (order.subMerchantKey) {
    basketItem.subMerchantKey = order.subMerchantKey;
    basketItem.subMerchantPrice = formatPrice(order.subMerchantPrice);
  }

  const request = {
    locale: Iyzipay.LOCALE.TR,
    conversationId: order.id,
    price,
    paidPrice: price,
    currency: Iyzipay.CURRENCY.TRY,
    basketId: order.id,
    paymentGroup: Iyzipay.PAYMENT_GROUP.PRODUCT,
    callbackUrl: process.env.IYZICO_CALLBACK_URL,
    enabledInstallments: [1], // tek çekim
    buyer: {
      id: user.id,
      name,
      surname,
      gsmNumber: user.phone || '+905350000000',
      email: user.email,
      identityNumber: '11111111111', // sandbox placeholder (KVKK: gerçek TC toplanmıyor)
      registrationAddress: business.address || 'Adres',
      ip: ip || '0.0.0.0',
      city: business.city || 'Istanbul',
      country: 'Turkey',
      zipCode: '34000',
    },
    shippingAddress: {
      contactName: user.name || 'Müşteri',
      city: business.city || 'Istanbul',
      country: 'Turkey',
      address: business.address || 'Adres',
      zipCode: '34000',
    },
    billingAddress: {
      contactName: user.name || 'Müşteri',
      city: business.city || 'Istanbul',
      country: 'Turkey',
      address: business.address || 'Adres',
      zipCode: '34000',
    },
    basketItems: [basketItem],
  };

  const result = await call('checkoutFormInitialize', 'create', request);
  if (!result || result.status !== 'success') {
    const msg = result?.errorMessage || 'iyzico checkout başlatılamadı';
    logger.error(`[iyzico] checkout init başarısız: ${msg} (order ${order.id})`);
    throw new Error(msg);
  }
  return {
    token: result.token,
    checkoutFormContent: result.checkoutFormContent,
    paymentPageUrl: result.paymentPageUrl,
    conversationId: result.conversationId,
    tokenExpireTime: result.tokenExpireTime,
  };
};

/** Ödeme sonucunu iyzico'dan çek (OTORİTE). */
const retrieveCheckoutForm = (token, conversationId) =>
  call('checkoutForm', 'retrieve', {
    locale: Iyzipay.LOCALE.TR,
    conversationId,
    token,
  });

/** Alt üye işyeri (sub-merchant) oluştur. business alanlarından request kurar. */
const buildSubMerchantRequest = (business) => {
  const base = {
    locale: Iyzipay.LOCALE.TR,
    conversationId: business.id,
    subMerchantExternalId: business.id,
    subMerchantType: business.subMerchantType,
    address: business.address,
    email: business.owner?.email || business.email,
    gsmNumber: business.gsmNumber || business.phone,
    name: business.name,
    iban: business.iban,
    currency: Iyzipay.CURRENCY.TRY,
  };
  if (business.subMerchantType === Iyzipay.SUB_MERCHANT_TYPE.PERSONAL) {
    return {
      ...base,
      contactName: business.contactName,
      contactSurname: business.contactSurname,
      identityNumber: business.identityNumber,
    };
  }
  // PRIVATE_COMPANY / LIMITED_OR_JOINT_STOCK_COMPANY
  return {
    ...base,
    taxOffice: business.taxOffice,
    taxNumber: business.taxNumber,
    legalCompanyTitle: business.legalCompanyTitle,
  };
};

const createSubMerchant = async (business) => {
  const result = await call('subMerchant', 'create', buildSubMerchantRequest(business));
  if (!result || result.status !== 'success') {
    throw new Error(result?.errorMessage || 'Alt üye işyeri oluşturulamadı');
  }
  return result; // result.subMerchantKey
};

const updateSubMerchant = async (business) => {
  const request = { ...buildSubMerchantRequest(business), subMerchantKey: business.subMerchantKey };
  const result = await call('subMerchant', 'update', request);
  if (!result || result.status !== 'success') {
    throw new Error(result?.errorMessage || 'Alt üye işyeri güncellenemedi');
  }
  return result;
};

/** Satıcı kırılımını ONAYLA — fonları havuzdan satıcıya serbest bırakır (teslimde çağrılır). */
const approveItem = async (paymentTransactionId, conversationId) => {
  const result = await call('approval', 'create', {
    locale: Iyzipay.LOCALE.TR,
    conversationId,
    paymentTransactionId,
  });
  if (!result || result.status !== 'success') {
    throw new Error(result?.errorMessage || 'Onay (approval) başarısız');
  }
  return result;
};

const disapproveItem = (paymentTransactionId, conversationId) =>
  call('disapproval', 'create', {
    locale: Iyzipay.LOCALE.TR,
    conversationId,
    paymentTransactionId,
  });

/** Tek kalem (item) iadesi — alıcıya parayı geri verir. price = iade tutarı (alıcı ödemesi). */
const refundItem = async ({ paymentTransactionId, price, ip, conversationId }) => {
  const result = await call('refund', 'create', {
    locale: Iyzipay.LOCALE.TR,
    conversationId,
    paymentTransactionId,
    price: formatPrice(price),
    ip: ip || '0.0.0.0',
    currency: Iyzipay.CURRENCY.TRY,
  });
  if (!result || result.status !== 'success') {
    throw new Error(result?.errorMessage || 'İade (refund) başarısız');
  }
  return result;
};

/** Tüm ödemeyi iptal et (aynı gün, mutabakat öncesi) — komisyon dahil tam geri alma. */
const cancelPayment = async ({ paymentId, ip, conversationId }) => {
  const result = await call('cancel', 'create', {
    locale: Iyzipay.LOCALE.TR,
    conversationId,
    paymentId,
    ip: ip || '0.0.0.0',
  });
  if (!result || result.status !== 'success') {
    throw new Error(result?.errorMessage || 'İptal (cancel) başarısız');
  }
  return result;
};

/**
 * Webhook imza doğrulama (savunma katmanı). Asıl güvenlik sınırı, finalize'da yapılan
 * retrieve çağrısıdır (iyzico OTORİTE). İmza algoritması webhook sürümüne göre değişebildiğinden
 * varsayılan olarak ZORUNLU DEĞİL: eşleşmezse uyarı loglanır ama retrieve ile doğrulamaya devam edilir.
 * IYZICO_WEBHOOK_ENFORCE=true ise eşleşmeyen istek reddedilir.
 */
const verifyWebhookSignature = (rawBody, signatureHeader) => {
  const secret = process.env.IYZICO_WEBHOOK_SECRET || process.env.IYZICO_SECRET_KEY;
  if (!secret || !signatureHeader) {
    return { valid: false, enforced: process.env.IYZICO_WEBHOOK_ENFORCE === 'true' };
  }
  try {
    const body = Buffer.isBuffer(rawBody) ? rawBody : Buffer.from(String(rawBody || ''));
    const computed = crypto.createHmac('sha256', secret).update(body).digest('base64');
    const a = Buffer.from(computed);
    const b = Buffer.from(String(signatureHeader));
    const valid = a.length === b.length && crypto.timingSafeEqual(a, b);
    return { valid, enforced: process.env.IYZICO_WEBHOOK_ENFORCE === 'true' };
  } catch (e) {
    return { valid: false, enforced: process.env.IYZICO_WEBHOOK_ENFORCE === 'true' };
  }
};

module.exports = {
  isConfigured,
  COMMISSION_RATE: COMMISSION_RATE_VALUE,
  formatPrice,
  calcSubMerchantPrice,
  initializeCheckoutForm,
  retrieveCheckoutForm,
  createSubMerchant,
  updateSubMerchant,
  approveItem,
  disapproveItem,
  refundItem,
  cancelPayment,
  verifyWebhookSignature,
};
