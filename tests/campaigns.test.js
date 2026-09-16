jest.mock('../src/services/iyzicoService', () => ({
  calcSubMerchantPrice: (p) => Number((Number(p) * .9).toFixed(2)),
  initializeCheckoutForm: jest.fn().mockImplementation(async () => ({ token: require('crypto').randomUUID(), checkoutFormContent: '<html></html>' })),
  refundItem: jest.fn().mockResolvedValue({}),
}));
jest.mock('../src/services/notificationService', () => ({
  notifyNewOrder: jest.fn().mockResolvedValue(), notifyOrderStatus: jest.fn().mockResolvedValue(), createNotification: jest.fn().mockResolvedValue(),
}));
const request = require('supertest');
const app = require('../src/app');
const { Order, Coupon } = require('../src/models');
const service = require('../src/services/couponService');
const { resetDb, closeDb, createUser, createPackage, createCoupon, authHeader } = require('./helpers');
beforeEach(resetDb);
afterAll(closeDb);
const place = (user, pkg, coupon, extra = {}) => request(app).post('/api/orders').set(authHeader(user))
  .send({ packageId: pkg.id, couponCode: coupon?.code, ...extra });
const cancel = (user, id) => request(app).patch(`/api/orders/${id}/cancel`).set(authHeader(user));

async function fixture(options = {}) {
  const pkg = await createPackage({ discountedPrice: 199.9, originalPrice: 350, quantity: 10, remainingQuantity: 10 });
  const user = await createUser();
  const coupon = await createCoupon({ discountType: 'fixed', discountValue: 100, firstOrderOnly: true, perUserLimit: 1,
    isDiscoverable: true, businessIds: [pkg.businessId], merchantConsentConfirmed: true, budgetLimit: 1000, ...options });
  return { user, pkg, coupon };
}

test('first-order entitlement is reserved across concurrent checkouts', async () => {
  const { user, pkg, coupon } = await fixture();
  const results = await Promise.all([place(user, pkg, coupon), place(user, pkg, coupon)]);
  expect(results.map((r) => r.status).sort()).toEqual([201, 400]);
  expect((await Coupon.findByPk(coupon.id)).currentUsage).toBe(1);
});

test('budget is serialized across different buyers and released exactly once on unpaid cancellation', async () => {
  const { user, pkg, coupon } = await fixture({ budgetLimit: 100 });
  const other = await createUser();
  const results = await Promise.all([place(user, pkg, coupon), place(other, pkg, coupon)]);
  expect(results.map((r) => r.status).sort()).toEqual([201, 400]);
  const i = results.findIndex((r) => r.status === 201);
  const buyer = i === 0 ? user : other;
  await cancel(buyer, results[i].body.order.id);
  await cancel(buyer, results[i].body.order.id);
  expect((await service.usage(coupon.id)).budgetUsed).toBe(0);
  expect((await Coupon.findByPk(coupon.id)).currentUsage).toBe(0);
  expect((await place(user, pkg, coupon)).status).toBe(201);
});

test('paid refunds do not restore coupon or first-order entitlement, including hidden orders', async () => {
  const { user, pkg, coupon } = await fixture();
  const placed = await place(user, pkg, coupon);
  await Order.update({ status: 'pending', paymentStatus: 'paid', paidPrice: 99.9, paidAt: new Date(), paymentTransactionId: 'refund-test' }, { where: { id: placed.body.order.id } });
  expect((await cancel(user, placed.body.order.id)).status).toBe(200);
  await Order.destroy({ where: { id: placed.body.order.id } });
  expect((await place(user, pkg, coupon)).status).toBe(400);
  expect((await service.usage(coupon.id)).budgetUsed).toBe(100);
});

test('per-user limit also applies to campaigns for returning users', async () => {
  const { user, pkg, coupon } = await fixture({ firstOrderOnly: false });
  expect((await place(user, pkg, coupon)).status).toBe(201);
  expect((await place(user, pkg, coupon)).status).toBe(400);
});

test('scoped campaign rejects other businesses in both preview and checkout', async () => {
  const { user, coupon } = await fixture();
  const other = await createPackage({ discountedPrice: 200 });
  const quote = await request(app).post('/api/coupons/validate').set(authHeader(user)).send({ code: coupon.code, packageId: other.id });
  expect(quote.status).toBe(400);
  expect((await place(user, other, coupon)).status).toBe(400);
  expect((await Coupon.findByPk(coupon.id)).currentUsage).toBe(0);
});

test('quote ignores forged order amount and uses package price with exact cents', async () => {
  const { user, pkg, coupon } = await fixture();
  const quote = await request(app).post('/api/coupons/validate').set(authHeader(user))
    .send({ code: coupon.code, packageId: pkg.id, orderAmount: 999999 });
  expect(quote.status).toBe(200);
  expect(quote.body.finalPrice).toBe(99.9);
  expect(quote.body.discountAmount).toBe(100);
  expect(quote.body.coupon).not.toHaveProperty('currentUsage');
  const order = await place(user, pkg, coupon, { expectedFinalPrice: 99.9 });
  expect(order.status).toBe(201);
  expect(Number(order.body.order.subMerchantPrice)).toBe(89.91);
});

test('price changes abort the checkout and roll back coupon budget', async () => {
  const { user, pkg, coupon } = await fixture();
  const response = await place(user, pkg, coupon, { expectedFinalPrice: 90 });
  expect(response.status).toBe(409);
  expect((await Coupon.findByPk(coupon.id)).currentUsage).toBe(0);
  expect((await service.usage(coupon.id)).budgetUsed).toBe(0);
});

test('fixed and percentage discounts never exceed the actual price or cap', async () => {
  const { user, pkg, coupon } = await fixture({ discountValue: 500 });
  const result = await place(user, pkg, coupon);
  expect(result.status).toBe(201);
  expect(Number(result.body.order.discountAmount)).toBe(199.9);
  expect(Number(result.body.order.finalPrice)).toBe(0);
  expect(service.discountFor({ discountType: 'percentage', discountValue: 50, maxDiscountAmount: 30 }, 199.9)).toBe(30);
});

test('wallet hides private and expired coupons and reports real completed savings only', async () => {
  const { user, pkg, coupon } = await fixture();
  await createCoupon({ code: 'PRIVATE' });
  await createCoupon({ isDiscoverable: true, expiresAt: new Date(0) });
  const before = await request(app).get('/api/coupons/mine').set(authHeader(user));
  expect(before.status).toBe(200);
  expect(before.body.coupons.map((c) => c.id)).toEqual([coupon.id]);
  expect(before.body.savings.totalSaved).toBe(0);
  const result = await place(user, pkg, coupon);
  await Order.update({ status: 'picked_up', paymentStatus: 'paid', paidAt: new Date() }, { where: { id: result.body.order.id } });
  const after = await request(app).get('/api/coupons/mine').set(authHeader(user));
  expect(after.body.coupons[0].eligible).toBe(false);
  expect(after.body.savings).toEqual({ totalSaved: 250.1, rescuedPackages: 1 });
});

test('campaign package list is scoped and never poisons public package cache', async () => {
  const { user, pkg, coupon } = await fixture({ minOrderAmount: 150 });
  const other = await createPackage({ discountedPrice: 200 });
  await createPackage({ businessId: pkg.businessId, discountedPrice: 50, remainingQuantity: 2 });
  const url = `/api/coupons/${coupon.id}/packages`;
  const list = await request(app).get(url).set(authHeader(user));
  expect(list.status).toBe(200);
  expect(list.body.data.map((p) => p.id)).toEqual([pkg.id]);
  const publicList = await request(app).get('/api/packages');
  expect(publicList.body.data.map((p) => p.id)).toContain(other.id);
});

test('publishing a discoverable campaign requires selected merchants and funding acknowledgement', async () => {
  const admin = await createUser({ role: 'admin' });
  const payload = { code: 'ILK100', title: 'İlk paketine özel', discountType: 'fixed', discountValue: 100,
    isDiscoverable: true, firstOrderOnly: true, perUserLimit: 1, expiresAt: new Date(Date.now() + 86400000).toISOString() };
  expect((await request(app).post('/api/coupons').set(authHeader(admin)).send(payload)).status).toBe(400);
  const draft = await request(app).post('/api/coupons').set(authHeader(admin)).send({ ...payload, isActive: false });
  expect(draft.status).toBe(201);
  const pkg = await createPackage();
  const active = await request(app).put(`/api/coupons/${draft.body.coupon.id}`).set(authHeader(admin))
    .send({ isActive: true, businessIds: [pkg.businessId], merchantConsentConfirmed: true });
  expect(active.status).toBe(200);
});

test('invalid discount updates are rejected and redemption history is archived, not deleted', async () => {
  const { user, pkg, coupon } = await fixture();
  const admin = await createUser({ role: 'admin' });
  expect((await request(app).put(`/api/coupons/${coupon.id}`).set(authHeader(admin)).send({ discountType: 'percentage', discountValue: 101 })).status).toBe(400);
  await place(user, pkg, coupon);
  expect((await request(app).put(`/api/coupons/${coupon.id}`).set(authHeader(admin)).send({ discountValue: 50 })).status).toBe(409);
  expect((await request(app).delete(`/api/coupons/${coupon.id}`).set(authHeader(admin))).status).toBe(200);
  expect((await Coupon.findByPk(coupon.id)).isActive).toBe(false);
  expect(await Order.count({ where: { couponId: coupon.id } })).toBe(1);
});

test('ordinary users cannot create campaigns or access other users coupon usage', async () => {
  const { user } = await fixture();
  expect((await request(app).get('/api/coupons/mine')).status).toBe(401);
  expect((await request(app).get('/api/coupons').set(authHeader(user))).status).toBe(403);
  expect((await request(app).post('/api/coupons').set(authHeader(user)).send({})).status).toBe(403);
});


test('ILK100 requires a 500 TL discounted subtotal and applies at the exact boundary', async () => {
  const { user, pkg, coupon } = await fixture({ minOrderAmount: 500 });
  await pkg.update({ discountedPrice: 250 });
  const low = await request(app).post('/api/coupons/validate').set(authHeader(user))
    .send({ code: coupon.code, packageId: pkg.id, quantity: 1, orderAmount: 9999 });
  expect(low.status).toBe(400);
  const quote = await request(app).post('/api/coupons/validate').set(authHeader(user))
    .send({ code: coupon.code, packageId: pkg.id, quantity: 2 });
  expect(quote.status).toBe(200);
  expect(quote.body.finalPrice).toBe(400);
  const list = await request(app).get(`/api/coupons/${coupon.id}/packages`).set(authHeader(user));
  expect(list.status).toBe(200);
  expect(list.body.data.map((p) => p.id)).toContain(pkg.id);
  const order = await place(user, pkg, coupon, { quantity: 2, expectedFinalPrice: 400 });
  expect(order.status).toBe(201);
  expect(Number(order.body.order.totalPrice)).toBe(500);
  expect(Number(order.body.order.finalPrice)).toBe(400);
});
