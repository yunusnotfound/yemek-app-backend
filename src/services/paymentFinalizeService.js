const { Order, SurprisePackage, Business, User, Coupon, sequelize } = require('../models');
const iyzicoService = require('./iyzicoService');
const { notifyNewOrder, createNotification } = require('./notificationService');
const cacheService = require('./cacheService');
const logger = require('./logger');
const settlementService = require('./settlementService');
const { Op } = require('sequelize');

// Kesin başarısızlık sayılan iyzico paymentStatus değerleri (terminal).
const isTerminalFailure = (paymentStatus) =>
  ['FAILURE', 'BANK_FAIL'].includes(String(paymentStatus || '').toUpperCase());

// checkoutForm.retrieve 'paymentStatus' alanı döndürür; threedsPayment.create ve
// payment.retrieve sonuçları döndürmez — orada status:'success' + paymentId varlığı
// SUCCESS'e, status:'failure' FAILURE'a eşdeğerdir.
const effectivePaymentStatus = (result) => {
  if (result?.paymentStatus) return String(result.paymentStatus).toUpperCase();
  if (result?.status === 'success' && result?.paymentId) return 'SUCCESS';
  if (result?.status === 'failure') return 'FAILURE';
  return '';
};

// Stok iade et + siparişi iptal et — yalnız hâlâ awaiting_payment ise (idempotent, yarış güvenli).
const releaseStockGuarded = async (order, reason, t) => {
  const [n] = await Order.update(
    { status: 'cancelled', couponReleased: true, paymentStatus: 'failed', paymentError: String(reason || '').slice(0, 500) },
    { where: { id: order.id, status: 'awaiting_payment' }, transaction: t }
  );
  if (n === 1) {
    await SurprisePackage.update(
      { remainingQuantity: sequelize.literal(`"remainingQuantity" + ${parseInt(order.quantity)}`) },
      { where: { id: order.packageId }, transaction: t }
    );
    // Kupon kullanımı sipariş oluşturulurken artırıldı; ödeme tamamlanmadan iptal
    // oluyorsa geri ver — aksi halde limitli kupon hiç ödemeyen kullanıcılarca tükenir.
    // GREATEST ile 0'ın altına inmez.
    if (order.couponId) {
      await Coupon.update(
        { currentUsage: sequelize.literal('GREATEST("currentUsage" - 1, 0)') },
        { where: { id: order.couponId }, transaction: t }
      );
    }
  }
  return n === 1;
};

// Ödeme başarılı olduktan sonra (txn DIŞINDA) işletme + müşteri bildirimleri.
const notifyPaid = async (order) => {
  try {
    const pkg = await SurprisePackage.findByPk(order.packageId, {
      include: [{ model: Business, as: 'business' }],
    });
    if (pkg?.business) {
      await notifyNewOrder(pkg.business.ownerId, pkg.business.name, {
        orderId: order.id,
        packageTitle: pkg.title,
        pickupCode: order.pickupCode,
        totalPrice: order.finalPrice,
      });
    }
    await createNotification(
      order.userId,
      'Ödeme Alındı',
      'Ödemeniz başarıyla alındı, rezervasyonunuz onaylandı.',
      'order_status',
      { orderId: order.id, status: 'pending' }
    );
  } catch (e) {
    logger.error(`[finalize] bildirim hatası (order ${order.id}): ${e.message}`);
  }
};

/** Accept only a provider result bound to the stored checkout/basket/item.
 * conversationId is request correlation, not proof of which basket was paid.
 */
const finalize = async ({ token, conversationId, retrieveResult, source = 'callback', ip }) => {
  if (token !== undefined && (typeof token !== 'string' || token.length > 1024)) return { outcome: 'unknown' };
  const result = retrieveResult || (token && await iyzicoService.retrieveCheckoutForm(token, conversationId));
  if (!result) return { outcome: 'unknown' };
  const identity = token ? { paymentToken: token } : result.basketId ? { conversationId: String(result.basketId) } : null;
  if (!identity) return { outcome: 'unknown' };

  let paidOrder;
  let refundOrderId;
  const outcome = await sequelize.transaction(async (transaction) => {
    const order = await Order.findOne({ where: identity, transaction, lock: true });
    if (!order || order.paymentProvider !== 'iyzico' ||
        (conversationId && conversationId !== order.conversationId) ||
        (result.basketId && String(result.basketId) !== order.conversationId) ||
        (result.token && result.token !== order.paymentToken) ||
        (order.paymentId && result.paymentId && String(result.paymentId) !== order.paymentId)) {
      return { outcome: 'unknown' };
    }
    // Provider lookup errors (e.g. payment not found yet) are not a failed payment.
    if (result.status !== 'success') return { outcome: 'pending', orderId: order.id };
    const payStatus = effectivePaymentStatus(result);
    if (payStatus === 'SUCCESS') {
      const item = result.itemTransactions?.[0];
      if (String(result.basketId || '') !== order.conversationId || !result.paymentId ||
          result.itemTransactions?.length !== 1 || String(item?.itemId || '') !== order.packageId ||
          !item.paymentTransactionId ||
          (item.subMerchantKey && item.subMerchantKey !== order.subMerchantKey)) {
        logger.error(`[finalize] payment binding rejected (order ${order.id}, source=${source})`);
        return { outcome: 'unknown' };
      }
      if (order.status === 'cancelled' && order.refundStatus === 'review' &&
          order.paymentError === 'fraud_review_cancelled' && Number(result.fraudStatus) === 1) {
        await order.update({ refundStatus: 'pending', fraudReview: false, paymentStatus: 'paid' }, { transaction });
        refundOrderId = order.id;
        return { outcome: 'refund_pending', orderId: order.id };
      }
      if (order.paymentStatus === 'refunded' || order.refundStatus !== 'none') {
        return { outcome: order.paymentStatus === 'refunded' ? 'refunded_late' : 'refund_pending', orderId: order.id };
      }
      if (order.paymentStatus === 'paid') return { outcome: 'already_paid', orderId: order.id, pickupCode: order.pickupCode };

      const paidPrice = Number(result.paidPrice);
      if (!Number.isFinite(paidPrice) || paidPrice <= 0) return { outcome: 'unknown' };
      const paymentFields = { paidPrice, paymentId: String(result.paymentId),
        paymentTransactionId: String(item.paymentTransactionId), paidAt: new Date() };
      const fraud = Number(result.fraudStatus);
      const mismatch = result.currency !== 'TRY' ||
        Math.round(paidPrice * 100) !== Math.round(Number(order.finalPrice) * 100);

      // Persist money evidence before releasing stock or attempting a refund.
      if (mismatch || order.status !== 'awaiting_payment' || fraud === -1) {
        await releaseStockGuarded(order, mismatch ? 'amount_or_currency_mismatch' : 'payment_not_fulfillable', transaction);
        await order.update({ ...paymentFields, status: 'cancelled', paymentStatus: 'paid',
          refundStatus: result.currency === 'TRY' && fraud !== -1 ? 'pending' : 'review',
          refundRequestedAt: new Date(), fraudReview: false,
          paymentError: mismatch ? 'amount_or_currency_mismatch' : 'payment_not_fulfillable' }, { transaction });
        refundOrderId = order.id;
        return { outcome: mismatch ? 'amount_mismatch' : 'refund_pending', orderId: order.id };
      }
      if (fraud !== 1) {
        await order.update({ ...paymentFields, fraudReview: true, paymentError: 'fraud_review' }, { transaction });
        return { outcome: 'review', orderId: order.id };
      }
      await order.update({ ...paymentFields, status: 'pending', paymentStatus: 'paid',
        settlementStatus: order.subMerchantKey ? 'held' : 'none',
        fraudReview: false, paymentError: null }, { transaction });
      if (result.cardUserKey && result.cardToken) {
        await User.update({ cardUserKey: result.cardUserKey },
          { where: { id: order.userId, cardUserKey: null }, transaction });
      }
      paidOrder = order;
      return { outcome: 'paid', orderId: order.id, pickupCode: order.pickupCode };
    }
    if (isTerminalFailure(payStatus)) {
      if (order.paymentStatus === 'paid' || order.paidPrice) return { outcome: 'review', orderId: order.id };
      await releaseStockGuarded(order, `failed_${payStatus}`, transaction);
      return { outcome: 'failed', orderId: order.id };
    }
    return { outcome: 'pending', orderId: order.id };
  });
  if (refundOrderId) {
    const refund = await settlementService.processRefund(refundOrderId, ip);
    if (refund.refunded && outcome.outcome === 'refund_pending') outcome.outcome = 'refunded_late';
  }
  if (paidOrder) await notifyPaid(paidOrder);
  if (paidOrder || refundOrderId || outcome.outcome === 'failed') await cacheService.invalidateNamespace('packages:list');
  return outcome;
};

/**
 * Süresi dolan ödenmemiş hold'u iptal et + stoğu iade et (reaper kullanır).
 * retrieve ile ödeme kontrolü ZATEN yapıldıktan SONRA çağrılır.
 */
const expireUnpaidHold = async (orderId) => {
  const t = await sequelize.transaction();
  try {
    const order = await Order.findByPk(orderId, { transaction: t, lock: true });
    if (!order || order.status !== 'awaiting_payment' || order.fraudReview || Number(order.paidPrice) > 0) {
      await t.commit();
      return false;
    }
    const released = await releaseStockGuarded(order, 'hold_expired', t);
    await t.commit();
    if (released) {
      await cacheService.invalidateNamespace('packages:list');
      try {
        await createNotification(
          order.userId,
          'Rezervasyon İptal Edildi',
          'Ödeme tamamlanmadığı için rezervasyonunuz iptal edildi.',
          'order_status',
          { orderId: order.id, status: 'cancelled' }
        );
      } catch (_) { /* yut */ }
    }
    return released;
  } catch (e) {
    await t.rollback();
    throw e;
  }
};

// Continue checking recently cancelled checkouts: a delayed charge must remain
// discoverable even if every callback/webhook was lost.
const reconcileCancelledPayments = async () => {
  const orders = await Order.findAll({ where: {
    status: 'cancelled', paymentProvider: 'iyzico',
    paymentStatus: { [Op.in]: ['pending', 'failed'] },
    refundStatus: { [Op.in]: ['none', 'review'] },
    createdAt: { [Op.gt]: new Date(Date.now() - 7 * 86400000) },
  }, order: [['paymentCheckedAt', 'ASC NULLS FIRST']], limit: 100 });
  for (const order of orders) {
    try {
      if (order.paymentToken) {
        await finalize({ token: order.paymentToken, conversationId: order.conversationId, source: 'cancelled-reconciliation' });
      } else {
        const result = await iyzicoService.retrievePayment({ conversationId: order.conversationId, paymentId: order.paymentId });
        await finalize({ retrieveResult: result, conversationId: order.conversationId, source: 'cancelled-reconciliation' });
      }
    } catch (error) {
      logger.error(`[finalize] iptal sonrası ödeme kontrolü başarısız (order ${order.id})`);
    } finally {
      await Order.update({ paymentCheckedAt: new Date() }, { where: { id: order.id } });
    }
  }
};

module.exports = { finalize, expireUnpaidHold, reconcileCancelledPayments };
