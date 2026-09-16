const { Coupon, Order } = require('../models');
const { Op, fn, col, literal } = require('sequelize');

const cents = (value) => Math.round(Number(value) * 100);
const problem = (message, statusCode = 400) => Object.assign(new Error(message), { statusCode });
const discountFor = (coupon, total) => {
  const price = Math.max(0, cents(total));
  let discount = coupon.discountType === 'percentage'
    ? Math.round(price * Number(coupon.discountValue) / 100) : cents(coupon.discountValue);
  if (coupon.maxDiscountAmount != null) discount = Math.min(discount, cents(coupon.maxDiscountAmount));
  return Math.max(0, Math.min(price, discount)) / 100;
};

const aggregateUsage = async (couponIds, { transaction, includeCompleted = true } = {}) => {
  const result = new Map(couponIds.map((id) => [id, { budgetUsed: 0, ...(includeCompleted ? { completedOrders: 0 } : {}) }]));
  if (!result.size) return result;
  const attributes = ['couponId', [fn('SUM', col('discountAmount')), 'budgetUsed']];
  if (includeCompleted) attributes.push([literal(`SUM(CASE WHEN "status" = 'picked_up' THEN 1 ELSE 0 END)`), 'completedOrders']);
  const rows = await Order.findAll({
    attributes, where: { couponId: { [Op.in]: [...result.keys()] }, couponReleased: false },
    group: ['couponId'], transaction, paranoid: false, raw: true,
  });
  for (const row of rows) result.set(row.couponId, {
    budgetUsed: Number(row.budgetUsed) || 0,
    ...(includeCompleted ? { completedOrders: Number(row.completedOrders) || 0 } : {}),
  });
  return result;
};

const usageMany = (couponIds, transaction) => aggregateUsage(couponIds, { transaction });
const usage = async (couponId, transaction) => (await usageMany([couponId], transaction)).get(couponId);
const budgetUsed = async (couponId, transaction) => Number(await Order.sum('discountAmount', {
  where: { couponId, couponReleased: false }, transaction, paranoid: false,
})) || 0;

const hasPreviousOrder = async (userId, transaction) => Boolean(await Order.findOne({
  attributes: ['id'], where: { userId, [Op.or]: [
    { status: { [Op.ne]: 'cancelled' } }, { paidAt: { [Op.ne]: null } },
    { paymentStatus: { [Op.in]: ['paid', 'refunded', 'partially_refunded'] } },
  ] }, transaction, paranoid: false,
}));

// On order creation the caller holds the buyer and coupon row locks. Pending
// orders reserve both the per-user entitlement and nominal campaign budget.
const checkWithContext = async (coupon, userId, { total, businessId, transaction } = {}, context) => {
  if (!coupon || !coupon.isActive || new Date(coupon.expiresAt) <= new Date()) {
    throw problem('Geçersiz veya süresi dolmuş kupon kodu', 404);
  }
  if (coupon.currentUsage >= coupon.maxUsage) throw problem('Kupon kullanım limiti dolmuş');
  if (coupon.firstOrderOnly) {
    const previous = context ? context.hasPreviousOrder : await hasPreviousOrder(userId, transaction);
    if (previous) throw problem('Bu kupon yalnızca ilk siparişte geçerli. Bekleyen siparişiniz varsa önce tamamlayın veya iptal edin.');
  }
  if (coupon.perUserLimit != null) {
    const used = context ? context.userUsage.get(coupon.id) || 0
      : await Order.count({ where: { userId, couponId: coupon.id, couponReleased: false }, transaction, paranoid: false });
    if (used >= coupon.perUserLimit) throw problem('Bu kupon için kişisel kullanım hakkınız doldu');
  }
  if (businessId && coupon.businessIds.length && !coupon.businessIds.includes(businessId)) {
    throw problem('Bu kupon seçili işletmelerde geçerli');
  }
  if (total != null && cents(total) < cents(coupon.minOrderAmount)) {
    throw problem(`Bu kupon minimum ${Number(coupon.minOrderAmount).toFixed(2)} TL siparişte geçerlidir`);
  }
  const discountAmount = total == null ? null : discountFor(coupon, total);
  if (coupon.budgetLimit != null) {
    const used = context ? context.campaignUsage.get(coupon.id)?.budgetUsed || 0 : await budgetUsed(coupon.id, transaction);
    if (cents(used) >= cents(coupon.budgetLimit) ||
        (discountAmount != null && cents(used) + cents(discountAmount) > cents(coupon.budgetLimit))) {
      throw problem('Kampanya bütçesi doldu; başka bir kupon seçebilirsiniz');
    }
  }
  return { discountAmount, finalPrice: total == null ? null : (cents(total) - cents(discountAmount)) / 100 };
};

// Only list previews share a request-scoped snapshot. Checkout always enters
// check() without it and reads the current usage under the caller's row locks.
const check = (coupon, userId, options) => checkWithContext(coupon, userId, options);

const eligibilityForMany = async (couponRows, userId, options = {}) => {
  const { transaction } = options;
  const userCouponIds = couponRows.filter((coupon) => coupon?.perUserLimit != null).map((coupon) => coupon.id);
  const budgetCouponIds = couponRows.filter((coupon) => coupon?.budgetLimit != null).map((coupon) => coupon.id);
  const [previous, userRows, campaignUsage] = await Promise.all([
    couponRows.some((coupon) => coupon?.firstOrderOnly) ? hasPreviousOrder(userId, transaction) : false,
    userCouponIds.length ? Order.findAll({
      attributes: ['couponId', [fn('COUNT', col('id')), 'used']],
      where: { userId, couponId: { [Op.in]: userCouponIds }, couponReleased: false },
      group: ['couponId'], transaction, paranoid: false, raw: true,
    }) : [],
    aggregateUsage(budgetCouponIds, { transaction, includeCompleted: false }),
  ]);
  const context = { hasPreviousOrder: previous, userUsage: new Map(userRows.map((row) => [row.couponId, Number(row.used)])), campaignUsage };
  return Promise.all(couponRows.map(async (coupon) => {
    try {
      await checkWithContext(coupon, userId, options, context);
      return { eligible: true };
    } catch (error) {
      if (!error.statusCode) throw error;
      return { eligible: false, reason: error.message };
    }
  }));
};

const reserve = async (code, userId, options) => {
  const coupon = await Coupon.findOne({ where: { code: code.trim().toUpperCase() }, transaction: options.transaction, lock: true });
  const quote = await check(coupon, userId, options);
  await coupon.increment('currentUsage', { transaction: options.transaction });
  return { ...quote, couponId: coupon.id };
};

const present = (coupon) => {
  const { id, code, title, discountType, discountValue, minOrderAmount, maxDiscountAmount,
    firstOrderOnly, perUserLimit, expiresAt, businessIds } = coupon;
  return { id, code, title, discountType, discountValue, minOrderAmount, maxDiscountAmount,
    firstOrderOnly, perUserLimit, expiresAt, businessIds };
};

module.exports = { cents, problem, discountFor, usage, usageMany, budgetUsed, check, eligibilityForMany, reserve, present };
