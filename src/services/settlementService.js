const { Order } = require('../models');
const { Op } = require('sequelize');
const iyzicoService = require('./iyzicoService');
const logger = require('./logger');

/**
 * Teslim (picked_up) sonrası satıcı fonlarını serbest bırakmak için iyzico approval.
 * Hata toleranslı: başarısız olursa settlementStatus 'held' kalır, retryHeldApprovals tekrar dener.
 * Ücretsiz/ödemesiz siparişte (paymentTransactionId yok) sessizce atlar.
 */
const approveOnPickup = async (order) => {
  if (!order || !order.paymentTransactionId || order.settlementStatus !== 'held') return;
  try {
    await iyzicoService.approveItem(order.paymentTransactionId, order.conversationId || order.id);
    await Order.update(
      { settlementStatus: 'approved', paymentError: null },
      { where: { id: order.id, settlementStatus: 'held' } }
    );
    logger.info(`[settlement] approval başarılı (order ${order.id})`);
  } catch (e) {
    await Order.update(
      { paymentError: `approval_failed: ${String(e.message).slice(0, 200)}` },
      { where: { id: order.id } }
    );
    logger.error(`[settlement] approval başarısız (order ${order.id}): ${e.message}`);
  }
};

/** Onaylanamamış (held) teslim edilmiş siparişleri periyodik tekrar onayla (retry cron). */
const retryHeldApprovals = async () => {
  const orders = await Order.findAll({
    where: {
      status: 'picked_up',
      settlementStatus: 'held',
      paymentTransactionId: { [Op.ne]: null },
    },
    limit: 100,
    order: [['updatedAt', 'ASC']],
  });
  for (const o of orders) {
    await approveOnPickup(o);
  }
  if (orders.length) logger.info(`[settlement] ${orders.length} bekleyen approval yeniden denendi`);
};

/**
 * Ödenmiş bir siparişi iyzico'da iade et (kalem iadesi). Çağıran, başarıdan SONRA
 * sipariş durumunu (refunded) güncellemelidir. Para güvenliği için önce iade, sonra DB.
 * @returns {{ refunded: boolean, amount?: number }}
 */
const refundOrder = async (order, ip) => {
  if (order.paymentStatus !== 'paid' || !order.paymentTransactionId) {
    return { refunded: false };
  }
  const price = Number(order.paidPrice ?? order.finalPrice);
  await iyzicoService.refundItem({
    paymentTransactionId: order.paymentTransactionId,
    price,
    ip,
    conversationId: order.conversationId || order.id,
  });
  return { refunded: true, amount: price };
};

module.exports = { approveOnPickup, retryHeldApprovals, refundOrder };
