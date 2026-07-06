// Kupon matematiği + kullanım sayacı davranışını sipariş oluşturma ucundan test
// eder. iyzico/bildirim mock'lanır (ücretli sipariş -> awaiting_payment).
jest.mock('../src/services/iyzicoService', () => ({
  calcSubMerchantPrice: (p) => Number((Number(p) * 0.9).toFixed(2)),
  initializeCheckoutForm: jest.fn().mockResolvedValue({
    token: 'test-token',
    checkoutFormContent: '<html></html>',
    paymentPageUrl: 'https://sandbox.example/pay',
  }),
  initializeThreeDS: jest.fn().mockResolvedValue({ threeDSHtmlContent: '<html></html>' }),
  refundItem: jest.fn().mockResolvedValue({}),
}));
jest.mock('../src/services/notificationService', () => ({
  notifyNewOrder: jest.fn().mockResolvedValue(),
  notifyOrderStatus: jest.fn().mockResolvedValue(),
  createNotification: jest.fn().mockResolvedValue(),
}));

const request = require('supertest');
const app = require('../src/app');
const { Coupon } = require('../src/models');
const {
  resetDb,
  closeDb,
  createUser,
  createPackage,
  createCoupon,
  authHeader,
} = require('./helpers');

beforeEach(resetDb);
afterAll(closeDb);

async function orderWithCoupon(code, { discountedPrice = 100, quantity = 1 } = {}) {
  const pkg = await createPackage({ discountedPrice, quantity: 10, remainingQuantity: 10 });
  const user = await createUser();
  return request(app)
    .post('/api/orders')
    .set(authHeader(user))
    .send({ packageId: pkg.id, quantity, couponCode: code });
}

describe('Kupon matematiği (POST /api/orders)', () => {
  test('yüzde indirim: 100 TL üzerinden %10 -> finalPrice 90', async () => {
    const coupon = await createCoupon({ discountType: 'percentage', discountValue: 10 });
    const res = await orderWithCoupon(coupon.code);
    expect(res.status).toBe(201);
    expect(parseFloat(res.body.order.finalPrice)).toBeCloseTo(90);
    expect(parseFloat(res.body.order.discountAmount)).toBeCloseTo(10);
  });

  test('sabit indirim: 100 TL - 30 TL -> finalPrice 70', async () => {
    const coupon = await createCoupon({ discountType: 'fixed', discountValue: 30 });
    const res = await orderWithCoupon(coupon.code);
    expect(res.status).toBe(201);
    expect(parseFloat(res.body.order.finalPrice)).toBeCloseTo(70);
  });

  test('minOrderAmount altındaki sipariş reddedilir (400)', async () => {
    const coupon = await createCoupon({ discountType: 'fixed', discountValue: 10, minOrderAmount: 200 });
    const res = await orderWithCoupon(coupon.code, { discountedPrice: 100 });
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/minimum/i);
  });

  test('kullanım limiti dolmuş kupon reddedilir (400)', async () => {
    const coupon = await createCoupon({ maxUsage: 1, currentUsage: 1 });
    const res = await orderWithCoupon(coupon.code);
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/limit/i);
  });

  test('süresi geçmiş kupon geçersiz (404)', async () => {
    const coupon = await createCoupon({ expiresAt: new Date(Date.now() - 1000) });
    const res = await orderWithCoupon(coupon.code);
    expect(res.status).toBe(404);
  });
});

describe('Kupon kullanımı — ödeme tamamlanmadan iptalde geri verilir (KRİTİK)', () => {
  test('sipariş kuponu artırır; awaiting_payment iptali currentUsage azaltır', async () => {
    const coupon = await createCoupon({ maxUsage: 5, currentUsage: 0, discountType: 'percentage', discountValue: 10 });
    const pkg = await createPackage({ discountedPrice: 100, quantity: 5, remainingQuantity: 5 });
    const user = await createUser();

    const create = await request(app)
      .post('/api/orders')
      .set(authHeader(user))
      .send({ packageId: pkg.id, quantity: 1, couponCode: coupon.code });
    expect(create.status).toBe(201);
    expect(create.body.order.status).toBe('awaiting_payment');
    expect((await Coupon.findByPk(coupon.id)).currentUsage).toBe(1);

    const cancel = await request(app)
      .patch(`/api/orders/${create.body.order.id}/cancel`)
      .set(authHeader(user));
    expect(cancel.status).toBe(200);
    expect((await Coupon.findByPk(coupon.id)).currentUsage).toBe(0);
  });
});
