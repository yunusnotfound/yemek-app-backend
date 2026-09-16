const { Order, SurprisePackage, Coupon, sequelize } = require('../models');
const settlementService = require('./settlementService');
const cacheService = require('./cacheService');

// Reserve cancellation and money movement atomically before contacting iyzico.
// Every delivery transition guards the old status, so it cannot race the refund.
const cancelOrder = async (id, { ip, allowPickedUp = false } = {}) => {
  await sequelize.transaction(async (transaction) => {
    const order = await Order.findByPk(id, { transaction, lock: true });
    if (!order) throw Object.assign(new Error('Sipariş bulunamadı'), { statusCode: 404 });
    if (order.status === 'picked_up' && !allowPickedUp) {
      throw Object.assign(new Error('Teslim alınmış sipariş iptal edilemez'), { statusCode: 409 });
    }
    const oldStatus = order.status;
    const needsRefund = Number(order.paidPrice) > 0 ||
      (order.paymentStatus === 'paid' && Number(order.finalPrice) > 0);
    const refundStatus = needsRefund && order.refundStatus === 'none'
      ? (order.paymentTransactionId && !order.fraudReview ? 'pending' : 'review') : order.refundStatus;
    await order.update({ status: 'cancelled', refundStatus,
      couponReleased: order.couponReleased || oldStatus === 'awaiting_payment',
      ...(order.fraudReview ? { paymentError: 'fraud_review_cancelled' } : {}),
      ...(needsRefund && !order.refundRequestedAt ? { refundRequestedAt: new Date() } : {}) }, { transaction });
    if (['awaiting_payment', 'pending', 'confirmed'].includes(oldStatus)) {
      await SurprisePackage.increment('remainingQuantity', { by: order.quantity, where: { id: order.packageId }, transaction });
      if (oldStatus === 'awaiting_payment' && order.couponId) {
        await Coupon.update({ currentUsage: sequelize.literal('GREATEST("currentUsage" - 1, 0)') },
          { where: { id: order.couponId }, transaction });
      }
    }
  });
  await cacheService.invalidateNamespace('packages:list');
  await settlementService.processRefund(id, ip);
  return Order.findByPk(id);
};

const cancellationMessage = (order) => order.paymentStatus === 'refunded'
  ? 'Sipariş iptal edildi ve ödeme iade edildi'
  : order.refundStatus !== 'none' ? 'Sipariş iptal edildi. Ödeme iadesi takip ediliyor.' : 'Sipariş iptal edildi';

module.exports = { cancelOrder, cancellationMessage };
