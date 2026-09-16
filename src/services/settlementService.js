const { Order, sequelize } = require('../models');
const { Op } = require('sequelize');
const iyzicoService = require('./iyzicoService');
const logger = require('./logger');

/**
 * Teslim (picked_up) sonrası satıcı fonlarını serbest bırakmak için iyzico approval.
 * Hata toleranslı: başarısız olursa settlementStatus 'held' kalır, retryHeldApprovals tekrar dener.
 * Ücretsiz/ödemesiz siparişte (paymentTransactionId yok) sessizce atlar.
 */
const approveOnPickup = async (order) => {
  if (!order) return;
  try {
    await sequelize.transaction(async (transaction) => {
      const fresh = await Order.findByPk(order.id, { transaction, lock: true });
      if (!fresh || fresh.status !== 'picked_up' || fresh.paymentStatus !== 'paid' ||
          fresh.refundStatus !== 'none' || !fresh.paymentTransactionId || fresh.settlementStatus !== 'held') return;
      await iyzicoService.approveItem(fresh.paymentTransactionId, fresh.conversationId || fresh.id);
      await fresh.update({ settlementStatus: 'approved', paymentError: null }, { transaction });
    });
  } catch (e) {
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

// Only a committed 'pending' reservation can initiate a refund. 'processing'
// survives crashes; a timeout is ambiguous and must never trigger a blind retry.
const processRefund = async (orderId, ip) => {
  const order = await sequelize.transaction(async (transaction) => {
    const current = await Order.findByPk(orderId, { transaction, lock: true });
    if (!current || current.status !== 'cancelled' || current.refundStatus !== 'pending') return null;
    if (!current.paymentTransactionId || !(Number(current.paidPrice) > 0)) {
      await current.update({ refundStatus: 'review', paymentError: 'refund_evidence_missing' }, { transaction });
      return null;
    }
    await current.update({ refundStatus: 'processing', refundAttemptedAt: new Date() }, { transaction });
    return current;
  });
  if (!order) return { refunded: false };
  const amount = Number(order.paidPrice);
  try {
    await iyzicoService.refundItem({ paymentTransactionId: order.paymentTransactionId,
      price: amount, ip, conversationId: order.conversationId || order.id });
    await Order.update({ refundStatus: 'completed', paymentStatus: 'refunded',
      settlementStatus: 'refunded', refundAmount: amount, paymentError: null },
      { where: { id: order.id, refundStatus: 'processing' } });
    return { refunded: true, amount };
  } catch (e) {
    await Order.update({ refundStatus: 'review', paymentError: `refund_review: ${String(e.message).slice(0, 200)}` },
      { where: { id: order.id, refundStatus: 'processing' } });
    logger.error(`[settlement] iade mutabakatı gerekli (order ${order.id})`);
    return { refunded: false };
  }
};

const retryPendingRefunds = async () => {
  // Stale in-flight requests may already have reached the bank. Surface them
  // for reconciliation instead of issuing the financial instruction twice.
  await Order.update({ refundStatus: 'review', paymentError: 'refund_response_unknown' }, {
    where: { refundStatus: 'processing', refundAttemptedAt: { [Op.lt]: new Date(Date.now() - 10 * 60 * 1000) } },
  });
  const orders = await Order.findAll({ where: { refundStatus: 'pending' }, limit: 100, order: [['refundRequestedAt', 'ASC']] });
  for (const order of orders) await processRefund(order.id);
};

module.exports = { approveOnPickup, retryHeldApprovals, processRefund, retryPendingRefunds };
