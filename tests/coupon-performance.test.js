const crypto = require('crypto');
const request = require('supertest');
const app = require('../src/app');
const { sequelize, Coupon, Order } = require('../src/models');
const coupons = require('../src/services/couponService');
const { resetDb, closeDb, createUser, createPackage, createCoupon, authHeader } = require('./helpers');

beforeEach(resetDb);
afterAll(closeDb);

async function createOrder(user, pkg, coupon, overrides = {}) {
  return Order.create({
    userId: user.id, packageId: pkg.id, couponId: coupon?.id,
    pickupCode: crypto.randomBytes(3).toString('hex').toUpperCase(),
    quantity: 1, totalPrice: 100, discountAmount: 10, finalPrice: 90,
    status: 'awaiting_payment', paymentStatus: 'pending', ...overrides,
  });
}

async function individualEligibility(rows, userId, options) {
  const results = [];
  for (const coupon of rows) {
    try {
      await coupons.check(coupon, userId, options);
      results.push({ eligible: true });
    } catch (error) {
      if (!error.statusCode) throw error;
      results.push({ eligible: false, reason: error.message });
    }
  }
  return results;
}

async function recordSql(action) {
  const originalLogging = sequelize.options.logging;
  const queries = [];
  sequelize.options.logging = (sql) => queries.push(sql);
  try {
    return { value: await action(), queries };
  } finally {
    sequelize.options.logging = originalLogging;
  }
}

test('bulk eligibility matches live checks for pending, cancelled, paid, refunded and hidden history', async () => {
  const pkg = await createPackage();
  const first = await createCoupon({ firstOrderOnly: true, perUserLimit: 1, budgetLimit: 10000 });
  const personal = await createCoupon({ perUserLimit: 1, budgetLimit: 10000 });
  const unlimited = await createCoupon();
  const rows = [first, personal, unlimited];
  const scenarios = [
    { name: 'new buyer', order: null, eligible: [true, true, true] },
    { name: 'pending checkout', order: {}, eligible: [false, false, true] },
    { name: 'released failed checkout', order: { status: 'cancelled', paymentStatus: 'failed', couponReleased: true }, eligible: [true, true, true] },
    { name: 'cancelled unpaid but retained coupon', order: { status: 'cancelled', paymentStatus: 'unpaid' }, eligible: [true, false, true] },
    { name: 'paid cancellation', order: { status: 'cancelled', paymentStatus: 'paid' }, eligible: [false, false, true] },
    { name: 'refund', order: { status: 'cancelled', paymentStatus: 'refunded' }, eligible: [false, false, true] },
    { name: 'partial refund', order: { status: 'cancelled', paymentStatus: 'partially_refunded' }, eligible: [false, false, true] },
    { name: 'paidAt survives failed status', order: { status: 'cancelled', paymentStatus: 'failed', paidAt: new Date(), couponReleased: true }, eligible: [false, true, true] },
    { name: 'hidden refund', order: { status: 'cancelled', paymentStatus: 'refunded' }, hidden: true, eligible: [false, false, true] },
    { name: 'unrelated completed order', order: { status: 'picked_up', paymentStatus: 'unpaid', couponId: null }, eligible: [false, true, true] },
  ];
  for (const scenario of scenarios) {
    const user = await createUser();
    if (scenario.order) {
      const order = await createOrder(user, pkg, personal, scenario.order);
      if (scenario.hidden) await order.destroy();
    }
    const bulk = await coupons.eligibilityForMany(rows, user.id);
    expect({ name: scenario.name, eligible: bulk.map((entry) => entry.eligible) })
      .toEqual({ name: scenario.name, eligible: scenario.eligible });
    expect(bulk).toEqual(await individualEligibility(rows, user.id));
  }
});

test('bulk budget and completed totals include retained hidden orders and exclude released reservations', async () => {
  const pkg = await createPackage();
  const user = await createUser();
  const other = await createUser();
  const exhausted = await createCoupon({ budgetLimit: 30 });
  const available = await createCoupon({ budgetLimit: 30.01 });
  const empty = await createCoupon({ budgetLimit: 100 });
  for (const coupon of [exhausted, available]) {
    await createOrder(user, pkg, coupon);
    const hidden = await createOrder(other, pkg, coupon, { status: 'picked_up', paymentStatus: 'paid', paidAt: new Date() });
    await hidden.destroy();
    await createOrder(other, pkg, coupon, { status: 'cancelled', paymentStatus: 'refunded' });
    await createOrder(user, pkg, coupon, { status: 'cancelled', paymentStatus: 'failed', couponReleased: true, discountAmount: 500 });
    await createOrder(user, pkg, coupon, { status: 'picked_up', paymentStatus: 'unpaid', couponReleased: true, discountAmount: 500 });
  }
  const rows = [exhausted, available, empty];
  const bulk = await coupons.eligibilityForMany(rows, user.id);
  expect(bulk.map((entry) => entry.eligible)).toEqual([false, true, true]);
  expect(bulk).toEqual(await individualEligibility(rows, user.id));
  const { value: usage, queries } = await recordSql(() => coupons.usageMany(rows.map((coupon) => coupon.id)));
  expect(queries).toHaveLength(1);
  expect(usage.get(exhausted.id)).toEqual({ budgetUsed: 30, completedOrders: 1 });
  expect(usage.get(available.id)).toEqual({ budgetUsed: 30, completedOrders: 1 });
  expect(usage.get(empty.id)).toEqual({ budgetUsed: 0, completedOrders: 0 });
});

test('bulk previews retain validation order and exact budget, minimum and merchant boundaries', async () => {
  const user = await createUser();
  const pkg = await createPackage();
  const expired = await createCoupon({ expiresAt: new Date(0), currentUsage: 100 });
  const inactive = await createCoupon({ isActive: false });
  const maxed = await createCoupon({ currentUsage: 100, budgetLimit: 0 });
  const scoped = await createCoupon({ businessIds: [crypto.randomUUID()], minOrderAmount: 1000, budgetLimit: 0 });
  const minimum = await createCoupon({ minOrderAmount: 100.01, budgetLimit: 0 });
  const budget = await createCoupon({ discountType: 'fixed', discountValue: 10, budgetLimit: 19.99 });
  const exact = await createCoupon({ discountType: 'fixed', discountValue: 10, budgetLimit: 20, minOrderAmount: 100 });
  await createOrder(user, pkg, budget);
  await createOrder(user, pkg, exact);
  const rows = [expired, inactive, maxed, scoped, minimum, budget, exact];
  const options = { total: 100, businessId: pkg.businessId };
  const bulk = await coupons.eligibilityForMany(rows, user.id, options);
  expect(bulk).toEqual(await individualEligibility(rows, user.id, options));
  expect(bulk.map((entry) => entry.eligible)).toEqual([false, false, false, false, false, false, true]);
  expect(bulk[0].reason).toMatch(/süresi dolmuş/);
  expect(bulk[2].reason).toMatch(/kullanım limiti/);
  expect(bulk[3].reason).toMatch(/seçili işletmelerde/);
  expect(bulk[4].reason).toMatch(/minimum 100.01/);
  expect(bulk[5].reason).toMatch(/bütçesi doldu/);
});

test('checkout reads current budget inside its transaction without a completed-order count', async () => {
  const user = await createUser();
  const pkg = await createPackage();
  const coupon = await createCoupon({ discountType: 'fixed', discountValue: 10, budgetLimit: 20 });
  expect(await coupons.eligibilityForMany([coupon], user.id)).toEqual([{ eligible: true }]);
  await sequelize.transaction(async (transaction) => {
    await Order.create({
      userId: user.id, packageId: pkg.id, couponId: coupon.id,
      pickupCode: 'TXTEST', totalPrice: 100, finalPrice: 80, discountAmount: 20,
    }, { transaction });
    const { queries } = await recordSql(async () => {
      await expect(coupons.check(coupon, user.id, { total: 100, transaction })).rejects.toThrow(/bütçesi doldu/);
    });
    expect(queries).toHaveLength(1);
    expect(queries[0]).toContain(transaction.id);
    expect(queries[0]).toMatch(/sum\("discountAmount"\)/i);
    expect(queries[0]).not.toMatch(/count\(/i);
  });
});

test.each([10, 100])('wallet SQL stays bounded for %i campaigns and computes first-order eligibility once', async (count) => {
  const user = await createUser();
  await Coupon.bulkCreate(Array.from({ length: count }, (_, index) => ({
    code: `BULK${index}`, discountType: 'fixed', discountValue: 10,
    expiresAt: new Date(Date.now() + 86400000), isDiscoverable: true,
    firstOrderOnly: true, perUserLimit: 1, budgetLimit: 1000,
  })));
  const { value: response, queries } = await recordSql(() => request(app).get('/api/coupons/mine').set(authHeader(user)));
  expect(response.status).toBe(200);
  expect(response.body.coupons).toHaveLength(count);
  expect(response.body.coupons.every((coupon) => coupon.eligible)).toBe(true);
  expect(response.body.savings).toEqual({ rescuedPackages: 0, totalSaved: 0 });
  expect(queries.length).toBeLessThanOrEqual(6);
  expect(queries.filter((sql) => sql.includes('GROUP BY "couponId"'))).toHaveLength(2);
  expect(queries.filter((sql) => sql.includes('"Order"."status" !='))).toHaveLength(1);
});

test('admin campaign page aggregates 50 campaign totals in one query', async () => {
  const admin = await createUser({ role: 'admin' });
  const pkg = await createPackage();
  const rows = await Coupon.bulkCreate(Array.from({ length: 50 }, (_, index) => ({
    code: `ADMIN${index}`, discountType: 'fixed', discountValue: 10,
    expiresAt: new Date(Date.now() + 86400000),
  })));
  await createOrder(admin, pkg, rows[0], { status: 'picked_up', paymentStatus: 'unpaid' });
  const { value: response, queries } = await recordSql(() => request(app).get('/api/coupons?limit=50').set(authHeader(admin)));
  expect(response.status).toBe(200);
  expect(response.body.data).toHaveLength(50);
  expect(response.body.data.find((coupon) => coupon.id === rows[0].id)).toMatchObject({ budgetUsed: 10, completedOrders: 1 });
  expect(response.body.data.find((coupon) => coupon.id === rows[1].id)).toMatchObject({ budgetUsed: 0, completedOrders: 0 });
  expect(queries.length).toBeLessThanOrEqual(4);
  expect(queries.filter((sql) => sql.includes('FROM "Orders"'))).toHaveLength(1);
});

test('empty campaign batches do not query order history', async () => {
  const user = await createUser();
  const { queries } = await recordSql(async () => {
    expect(await coupons.eligibilityForMany([], user.id)).toEqual([]);
    expect(await coupons.usageMany([])).toEqual(new Map());
  });
  expect(queries).toHaveLength(0);
});
