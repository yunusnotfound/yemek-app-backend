// iyzico ve bildirim servisleri mock'lanır — ağ/side-effect olmadan sipariş
// akışının DB mantığını (atomik stok, yetki, iptal) test ederiz.
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
const { SurprisePackage, Order } = require('../src/models');
const {
  resetDb,
  closeDb,
  createUser,
  createBusiness,
  createPackage,
  authHeader,
} = require('./helpers');

beforeEach(resetDb);
afterAll(closeDb);

describe('POST /api/orders — stok & yarış', () => {
  test('remainingQuantity=1 iken 2 eşzamanlı sipariş: biri 201, diğeri 400 "Yetersiz stok"', async () => {
    const pkg = await createPackage({ quantity: 1, remainingQuantity: 1 });
    const a = await createUser();
    const b = await createUser();

    const [r1, r2] = await Promise.all([
      request(app).post('/api/orders').set(authHeader(a)).send({ packageId: pkg.id, quantity: 1 }),
      request(app).post('/api/orders').set(authHeader(b)).send({ packageId: pkg.id, quantity: 1 }),
    ]);

    const statuses = [r1.status, r2.status].sort();
    expect(statuses).toEqual([201, 400]);

    const failed = [r1, r2].find((r) => r.status === 400);
    expect(failed.body.message).toMatch(/Yetersiz stok/i);

    const fresh = await SurprisePackage.findByPk(pkg.id);
    expect(fresh.remainingQuantity).toBe(0);

    const orderCount = await Order.count();
    expect(orderCount).toBe(1);
  });

  test('yeterli stokta sipariş: 201 + stok azalır', async () => {
    const pkg = await createPackage({ quantity: 5, remainingQuantity: 5 });
    const user = await createUser();

    const res = await request(app)
      .post('/api/orders')
      .set(authHeader(user))
      .send({ packageId: pkg.id, quantity: 2 });

    expect(res.status).toBe(201);
    const fresh = await SurprisePackage.findByPk(pkg.id);
    expect(fresh.remainingQuantity).toBe(3);
  });

  test('onaylanmamış işletmenin paketinden sipariş verilemez (403)', async () => {
    const business = await createBusiness({ isApproved: false });
    const pkg = await createPackage({ businessId: business.id });
    const user = await createUser();

    const res = await request(app)
      .post('/api/orders')
      .set(authHeader(user))
      .send({ packageId: pkg.id, quantity: 1 });

    expect(res.status).toBe(403);
    const fresh = await SurprisePackage.findByPk(pkg.id);
    expect(fresh.remainingQuantity).toBe(pkg.remainingQuantity); // stok düşmedi
  });

  test('iptal edilen sipariş stoğu geri verir', async () => {
    const pkg = await createPackage({ quantity: 3, remainingQuantity: 3 });
    const user = await createUser();

    const create = await request(app)
      .post('/api/orders')
      .set(authHeader(user))
      .send({ packageId: pkg.id, quantity: 1 });
    expect(create.status).toBe(201);
    expect((await SurprisePackage.findByPk(pkg.id)).remainingQuantity).toBe(2);

    const orderId = create.body.order.id;
    const cancel = await request(app).patch(`/api/orders/${orderId}/cancel`).set(authHeader(user));
    expect(cancel.status).toBe(200);
    expect((await SurprisePackage.findByPk(pkg.id)).remainingQuantity).toBe(3);
  });
});

describe('GET /api/orders — yetki kapsamı (KRİTİK)', () => {
  test('business_owner TÜM siparişleri göremez; yalnız kendi siparişleri', async () => {
    const pkg = await createPackage();
    const customer = await createUser();
    await request(app).post('/api/orders').set(authHeader(customer)).send({ packageId: pkg.id, quantity: 1 });

    // Siparişi olmayan bir business_owner listeyi çeker -> boş dönmeli (eskiden HEPSİ dönüyordu).
    const owner = await createUser({ role: 'business_owner' });
    const res = await request(app).get('/api/orders').set(authHeader(owner));
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(0);
  });

  test('customer yalnız kendi siparişlerini görür', async () => {
    const pkg = await createPackage({ quantity: 10, remainingQuantity: 10 });
    const a = await createUser();
    const b = await createUser();
    await request(app).post('/api/orders').set(authHeader(a)).send({ packageId: pkg.id, quantity: 1 });
    await request(app).post('/api/orders').set(authHeader(b)).send({ packageId: pkg.id, quantity: 1 });

    const res = await request(app).get('/api/orders').set(authHeader(a));
    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].userId).toBe(a.id);
  });

  test('admin tüm siparişleri görür', async () => {
    const pkg = await createPackage({ quantity: 10, remainingQuantity: 10 });
    const a = await createUser();
    const b = await createUser();
    await request(app).post('/api/orders').set(authHeader(a)).send({ packageId: pkg.id, quantity: 1 });
    await request(app).post('/api/orders').set(authHeader(b)).send({ packageId: pkg.id, quantity: 1 });

    const admin = await createUser({ role: 'admin' });
    const res = await request(app).get('/api/orders').set(authHeader(admin));
    expect(res.status).toBe(200);
    expect(res.body.data.length).toBe(2);
  });
});
