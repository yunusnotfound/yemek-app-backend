const { Order, SurprisePackage, Business, sequelize } = require('../models');
const iyzicoService = require('./iyzicoService');
const { notifyNewOrder, createNotification } = require('./notificationService');
const cacheService = require('./cacheService');
const logger = require('./logger');

const PRICE_EPS = 0.01;

// Kesin başarısızlık sayılan iyzico paymentStatus değerleri (terminal).
const isTerminalFailure = (paymentStatus) =>
  ['FAILURE', 'BANK_FAIL'].includes(String(paymentStatus || '').toUpperCase());

// Stok iade et + siparişi iptal et — yalnız hâlâ awaiting_payment ise (idempotent, yarış güvenli).
const releaseStockGuarded = async (order, reason, t) => {
  const [n] = await Order.update(
    { status: 'cancelled', paymentStatus: 'failed', paymentError: String(reason || '').slice(0, 500) },
    { where: { id: order.id, status: 'awaiting_payment' }, transaction: t }
  );
  if (n === 1) {
    await SurprisePackage.update(
      { remainingQuantity: sequelize.literal(`"remainingQuantity" + ${parseInt(order.quantity)}`) },
      { where: { id: order.packageId }, transaction: t }
    );
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

/**
 * iyzico ödeme sonucunu idempotent şekilde kesinleştirir. callback / webhook / reaper paylaşır.
 * @returns {{ outcome: 'paid'|'already_paid'|'failed'|'pending'|'refunded_late'|'amount_mismatch'|'unknown', orderId?, pickupCode? }}
 */
const finalize = async ({ token, conversationId, retrieveResult, source = 'callback', ip }) => {
  // 1) OTORİTE sonucu al (verilmediyse iyzico'dan çek)
  let result = retrieveResult;
  if (!result) {
    if (!token) throw new Error('finalize: token veya retrieveResult gerekli');
    result = await iyzicoService.retrieveCheckoutForm(token, conversationId);
  }
  const convId = conversationId || result?.basketId || result?.conversationId;
  if (!convId) {
    logger.warn(`[finalize] conversationId çözülemedi (source=${source})`);
    return { outcome: 'unknown' };
  }

  const t = await sequelize.transaction();
  try {
    const order = await Order.findOne({ where: { conversationId: convId }, transaction: t, lock: true });
    if (!order) {
      await t.commit();
      logger.warn(`[finalize] sipariş yok conversationId=${convId} (source=${source})`);
      return { outcome: 'unknown' };
    }

    // 2) Idempotency — zaten ödenmişse hiçbir şey yapma
    if (order.paymentStatus === 'paid') {
      await t.commit();
      return { outcome: 'already_paid', orderId: order.id, pickupCode: order.pickupCode };
    }

    // 3) Sonucu değerlendir
    const apiOk = result && result.status === 'success';
    const payStatus = String(result?.paymentStatus || '').toUpperCase();
    const fraud = Number(result?.fraudStatus);
    const paidPrice = Number(result?.paidPrice);
    const currencyOk = !result?.currency || result.currency === 'TRY';
    const amountMatches = Number.isFinite(paidPrice) && Math.abs(paidPrice - Number(order.finalPrice)) < PRICE_EPS;
    const paymentTransactionId = result?.itemTransactions?.[0]?.paymentTransactionId || null;

    // 3a) BAŞARILI
    if (apiOk && payStatus === 'SUCCESS' && fraud !== -1 && currencyOk && amountMatches) {
      const [n] = await Order.update(
        {
          status: 'pending',
          paymentStatus: 'paid',
          paidPrice,
          paymentId: result.paymentId,
          paymentTransactionId,
          // Submerchant varsa fon havuzda (held -> pickup'ta approval); düz tahsilatta settlement yok.
          settlementStatus: order.subMerchantKey ? 'held' : 'none',
          paidAt: new Date(),
          paymentError: null,
        },
        { where: { id: order.id, status: 'awaiting_payment' }, transaction: t }
      );

      if (n === 0) {
        // Reaper TTL'de iptal etmiş ama ödeme gerçekleşmiş -> para alındı, hold yok -> otomatik iade.
        await t.commit();
        try {
          await iyzicoService.refundItem({ paymentTransactionId, price: paidPrice, ip, conversationId: convId });
          logger.warn(`[finalize] hold iptal sonrası ödeme -> otomatik iade (order ${order.id})`);
        } catch (e) {
          logger.error(`[finalize] geç iade başarısız (order ${order.id}): ${e.message}`);
        }
        return { outcome: 'refunded_late', orderId: order.id };
      }

      await t.commit();
      await notifyPaid(order);
      logger.info(`[finalize] ödeme tamamlandı (order ${order.id}, source=${source})`);
      return { outcome: 'paid', orderId: order.id, pickupCode: order.pickupCode };
    }

    // 3b) Tutar uyuşmazlığı (iyzico SUCCESS ama beklenenden farklı) -> onurlandırma, iade et
    if (apiOk && payStatus === 'SUCCESS' && !amountMatches) {
      await releaseStockGuarded(order, `amount_mismatch_${paidPrice}`, t);
      await t.commit();
      logger.error(`[finalize] TUTAR UYUŞMAZLIĞI order ${order.id}: beklenen ${order.finalPrice} gelen ${paidPrice}`);
      try {
        await iyzicoService.refundItem({ paymentTransactionId, price: paidPrice, ip, conversationId: convId });
      } catch (e) {
        logger.error(`[finalize] uyuşmazlık iadesi başarısız (order ${order.id}): ${e.message}`);
      }
      return { outcome: 'amount_mismatch', orderId: order.id };
    }

    // 3c) Terminal başarısızlık / fraud flag -> hold serbest bırak
    if (apiOk && (isTerminalFailure(payStatus) || fraud === -1)) {
      await releaseStockGuarded(order, fraud === -1 ? 'fraud_flagged' : `failed_${payStatus}`, t);
      await t.commit();
      logger.info(`[finalize] ödeme başarısız (order ${order.id}, status=${payStatus}, fraud=${fraud})`);
      return { outcome: 'failed', orderId: order.id };
    }

    // 3d) Belirsiz/yarım (3DS tamamlanmamış, inceleme) -> awaiting_payment bırak, reaper çözecek
    await t.commit();
    return { outcome: 'pending', orderId: order.id };
  } catch (e) {
    await t.rollback();
    throw e;
  }
};

/**
 * Süresi dolan ödenmemiş hold'u iptal et + stoğu iade et (reaper kullanır).
 * retrieve ile ödeme kontrolü ZATEN yapıldıktan SONRA çağrılır.
 */
const expireUnpaidHold = async (orderId) => {
  const t = await sequelize.transaction();
  try {
    const order = await Order.findByPk(orderId, { transaction: t, lock: true });
    if (!order || order.status !== 'awaiting_payment') {
      await t.commit();
      return false;
    }
    const released = await releaseStockGuarded(order, 'hold_expired', t);
    await t.commit();
    if (released) {
      await cacheService.delPattern('packages:list:*');
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

module.exports = { finalize, expireUnpaidHold };
