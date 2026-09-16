const { Order } = require('../models');
const iyzicoService = require('../services/iyzicoService');
const paymentFinalizeService = require('../services/paymentFinalizeService');
const logger = require('../services/logger');

// Webview'in algılayacağı sonuç sayfası URL'i (callback bunu 302 ile döndürür).
const resultBase = () =>
  process.env.IYZICO_RESULT_URL ||
  (process.env.IYZICO_CALLBACK_URL || '').replace(/\/iyzico\/callback$/, '/result');

/**
 * POST /payments/iyzico/callback — iyzico -> backend (JWT yok).
 * Form-urlencoded { token }. retrieve+finalize, sonra webview'i sonuç sayfasına yönlendir.
 */
exports.iyzicoCallback = async (req, res) => {
  const token = typeof req.body?.token === 'string' && req.body.token.length <= 1024 ? req.body.token : null;
  let orderId = null;
  let ok = false;
  try {
    if (token) {
      const r = await paymentFinalizeService.finalize({ token, source: 'callback', ip: req.ip });
      orderId = r.orderId || null;
      ok = r.outcome === 'paid' || r.outcome === 'already_paid';
    } else {
      logger.warn('[payments] callback token olmadan geldi');
    }
  } catch (e) {
    logger.error(`[payments] callback hata: ${e.message}`);
  }
  const url = `${resultBase()}?status=${ok ? 'ok' : 'fail'}${orderId ? `&orderId=${orderId}` : ''}`;
  return res.redirect(302, url);
};

/**
 * POST /payments/iyzico/3ds-callback — banka 3DS doğrulama ekranından dönüş (JWT yok).
 * Form-urlencoded { status, paymentId, conversationId, conversationData?, mdStatus }.
 * mdStatus=1 -> threedsPayment.create ile tahsilatı tamamla (OTORİTE bu çağrının sonucu),
 * aksi halde kesin başarısızlık -> hold hemen serbest bırakılır.
 */
exports.iyzico3dsCallback = async (req, res) => {
  const { paymentId, conversationId, conversationData, mdStatus } = req.body || {};
  let orderId = null;
  let ok = false;
  try {
    const order = typeof conversationId === 'string' && conversationId.length <= 64
      ? await Order.findOne({ where: { conversationId } }) : null;
    // A callback is public input. A matching provider payment must be proved
    // before capture; a forged failure callback must never cancel a hold.
    if (order && !order.paymentToken && typeof paymentId === 'string' && paymentId.length <= 128) {
      const matches = order.paymentId === paymentId;
      let verified = null;
      if (!matches && !order.paymentId) {
        // Compatibility for 3DS checkouts initialized before paymentId storage.
        verified = await iyzicoService.retrievePayment({ conversationId, paymentId });
      }
      if (matches || (verified?.status === 'success' && String(verified.basketId) === conversationId && String(verified.paymentId) === paymentId)) {
        orderId = order.id;
        if (String(mdStatus) === '1' && order.paymentStatus !== 'paid' && order.status === 'awaiting_payment') {
          await iyzicoService.completeThreeDS({ paymentId, conversationId,
            conversationData: typeof conversationData === 'string' ? conversationData : undefined }).catch(() => null);
        }
        // Always use an authoritative retrieval, including unsuccessful callbacks.
        const result = await iyzicoService.retrievePayment({ conversationId, paymentId });
        const r = await paymentFinalizeService.finalize({ retrieveResult: result, conversationId, source: '3ds-callback', ip: req.ip });
        ok = ['paid', 'already_paid'].includes(r.outcome);
      }
    }
  } catch (e) { logger.error(`[payments] 3ds-callback hata: ${e.message}`); }
  return res.redirect(302, `${resultBase()}?status=${ok ? 'ok' : 'fail'}${orderId ? `&orderId=${encodeURIComponent(orderId)}` : ''}`);
};

/** Signed notifications are hints; the provider API remains the payment authority. */
exports.iyzicoWebhook = async (req, res) => {
  try {
    const rawBody = req.body;
    const check = iyzicoService.verifyWebhookSignature(rawBody, req.headers['x-iyz-signature-v3']);
    if (!check.valid) return res.status(401).json({ message: 'invalid signature' });
    const payload = JSON.parse(rawBody.toString('utf8'));
    const conversationId = payload.paymentConversationId;
    if (typeof conversationId !== 'string' || conversationId.length > 64) {
      return res.status(400).json({ message: 'invalid payment reference' });
    }
    const order = await Order.findOne({ where: { conversationId } });
    if (!order) return res.status(200).json({ received: true });
    if ((payload.token && payload.token !== order.paymentToken) ||
        (order.paymentId && String(payload.iyziPaymentId || payload.paymentId) !== order.paymentId)) {
      return res.status(400).json({ message: 'payment reference mismatch' });
    }
    if (order.paymentToken) {
      await paymentFinalizeService.finalize({ token: order.paymentToken, conversationId, source: 'webhook', ip: req.ip });
    } else if (order.paymentProvider === 'iyzico') {
      const result = await iyzicoService.retrievePayment({ conversationId, paymentId: order.paymentId });
      await paymentFinalizeService.finalize({ retrieveResult: result, conversationId, source: 'webhook', ip: req.ip });
    }
    return res.status(200).json({ received: true });
  } catch (e) {
    logger.error(`[payments] webhook hata: ${e.message}`);
    // Preserve provider retries on transient failures.
    return res.status(503).json({ received: false });
  }
};

/**
 * GET /payments/:conversationId/status — mobil poll (auth + ownership). DB-only.
 * ?sync=1 -> callback gecikmişse tek seferlik retrieve+finalize tetikler.
 */
exports.getStatus = async (req, res, next) => {
  try {
    const { conversationId } = req.params;
    const order = await Order.findOne({ where: { conversationId } });
    if (!order) return res.status(404).json({ message: 'Sipariş bulunamadı' });
    if (order.userId !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({ message: 'Bu siparişi görme yetkiniz yok' });
    }

    if (req.query.sync === '1' && order.paymentStatus === 'pending') {
      try {
        if (order.paymentToken) {
          await paymentFinalizeService.finalize({
            token: order.paymentToken,
            conversationId,
            source: 'poll-sync',
            ip: req.ip,
          });
          await order.reload();
        } else if (order.paymentProvider === 'iyzico') {
          // 3DS siparişi -> payment.retrieve. Yalnız SUCCESS finalize edilir:
          // "bulunamadı" sonucu 3DS henüz tamamlanmamış demek olabilir (kullanıcı banka
          // sayfasında) — terminal sayıp erken iptal ETME; reaper TTL'de temizler.
          const result = await iyzicoService.retrievePayment({ conversationId, paymentId: order.paymentId }).catch(() => null);
          if (result?.status === 'success') {
            await paymentFinalizeService.finalize({
              retrieveResult: result,
              conversationId,
              source: 'poll-sync',
              ip: req.ip,
            });
            await order.reload();
          }
        }
      } catch (e) {
        logger.warn(`[payments] poll-sync finalize hata (order ${order.id}): ${e.message}`);
      }
    }

    res.json({
      orderId: order.id,
      conversationId: order.conversationId,
      status: order.status,
      paymentStatus: order.paymentStatus,
      finalPrice: order.finalPrice,
      paidPrice: order.paidPrice,
      pickupCode: order.paymentStatus === 'paid' ? order.pickupCode : null,
    });
  } catch (e) {
    next(e);
  }
};

/** GET /payments/result — webview landing (içerik önemsiz; mobil bu URL'i algılayıp kapatır). */
exports.paymentResult = (req, res) => {
  const ok = req.query.status === 'ok';
  res.set('Content-Type', 'text/html; charset=utf-8');
  res.send(
    `<!doctype html><html lang="tr"><head><meta charset="utf-8">` +
    `<meta name="viewport" content="width=device-width,initial-scale=1">` +
    `<title>Ödeme</title></head>` +
    `<body style="font-family:-apple-system,system-ui,sans-serif;text-align:center;padding:48px 24px;color:#1f2937">` +
    `<h2>${ok ? 'Ödeme tamamlandı' : 'Ödeme tamamlanamadı'}</h2>` +
    `<p>Uygulamaya dönebilirsiniz.</p></body></html>`
  );
};
