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
  const token = req.body?.token;
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
 * POST /payments/iyzico/webhook — imzalı yedek bildirim (raw body, app.js'te ayarlı).
 * İmza savunma katmanıdır; asıl doğrulama retrieve'dir. 200 döner (iyzico retry'ını engellemek için).
 */
exports.iyzicoWebhook = async (req, res) => {
  try {
    const signature = req.headers['x-iyz-signature'] || req.headers['x-iyzico-signature'];
    const rawBody = req.body; // express.raw -> Buffer
    const check = iyzicoService.verifyWebhookSignature(rawBody, signature);
    if (!check.valid && check.enforced) {
      logger.warn('[payments] webhook imza geçersiz (enforced) - reddedildi');
      return res.status(401).json({ message: 'invalid signature' });
    }
    if (!check.valid) {
      logger.warn('[payments] webhook imza doğrulanamadı - retrieve ile devam ediliyor');
    }

    let payload = {};
    try {
      payload = JSON.parse((Buffer.isBuffer(rawBody) ? rawBody.toString('utf8') : rawBody) || '{}');
    } catch (_) {
      payload = {};
    }

    let token = payload.token || payload.checkoutFormToken || null;
    const convId = payload.paymentConversationId || payload.conversationId || null;

    // Token yoksa siparişten kayıtlı token'ı al (retrieve için gerekli).
    if (!token && convId) {
      const order = await Order.findOne({ where: { conversationId: convId } });
      token = order?.paymentToken || null;
    }

    if (token) {
      await paymentFinalizeService.finalize({ token, conversationId: convId, source: 'webhook', ip: req.ip });
    } else {
      logger.warn('[payments] webhook token çözülemedi');
    }
    return res.status(200).json({ received: true });
  } catch (e) {
    logger.error(`[payments] webhook hata: ${e.message}`);
    return res.status(200).json({ received: true });
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

    if (req.query.sync === '1' && order.paymentStatus === 'pending' && order.paymentToken) {
      try {
        await paymentFinalizeService.finalize({
          token: order.paymentToken,
          conversationId,
          source: 'poll-sync',
          ip: req.ip,
        });
        await order.reload();
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
