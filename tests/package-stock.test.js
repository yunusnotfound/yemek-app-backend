jest.mock('../src/services/iyzicoService', () => ({
  calcSubMerchantPrice: (price) => Number((Number(price) * 0.9).toFixed(2)),
  initializeCheckoutForm: jest.fn().mockImplementation(async ({ order }) => ({
    token: `stock-test-${order.id}`,
    checkoutFormContent: '<html></html>',
    paymentPageUrl: 'https://sandbox.example/pay',
  })),
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
const cache = require('../src/services/cacheService');
const {
  resetDb, closeDb, createUser, createBusiness, createPackage, authHeader,
} = require('./helpers');

beforeEach(async () => {
  await resetDb();
  // Optional catalog Redis connects lazily; wait for actual readiness before
  // asserting cache hits instead of racing its first connection handshake.
  for (let attempt = 0; attempt < 200; attempt++) {
    if (await cache.getVersion('packages:list') !== null) return;
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error('Isolated stock-test Redis did not become ready');
});
afterEach(() => jest.restoreAllMocks());
afterAll(closeDb);

async function fixture(overrides = {}) {
  const owner = await createUser({ role: 'business_owner' });
  const business = await createBusiness({ ownerId: owner.id });
  const pkg = await createPackage({ businessId: business.id, ...overrides });
  return { owner, business, pkg };
}

function edit(owner, pkg, body) {
  return request(app).put(`/api/packages/${pkg.id}`).set(authHeader(owner))
    .send(body).timeout({ response: 10000, deadline: 12000 });
}

function reserve(customer, pkg, quantity) {
  return request(app).post('/api/orders').set(authHeader(customer))
    .send({ packageId: pkg.id, quantity })
    .timeout({ response: 10000, deadline: 12000 });
}

function expectStock(pkg, remainingQuantity, quantity) {
  expect(pkg).toMatchObject({ remainingQuantity, quantity });
}

describe('PUT /api/packages/:id — available stock follows total quantity changes', () => {
  test('created 5/5 becomes 10/10 in the update, owner list and warmed public list', async () => {
    const owner = await createUser({ role: 'business_owner' });
    const business = await createBusiness({ ownerId: owner.id });
    const created = await request(app).post('/api/packages').set(authHeader(owner)).send({
      businessId: business.id,
      title: 'Stock refill regression',
      originalPrice: 100,
      discountedPrice: 50,
      quantity: 5,
      pickupStart: '10:00',
      pickupEnd: '20:00',
      pickupDate: new Date(Date.now() + 3 * 86400000).toISOString().slice(0, 10),
    });
    expect(created.status).toBe(201);
    const pkg = created.body.package;
    expectStock(pkg, 5, 5);

    // Require a real warm Redis hit so stale-cache behavior cannot pass by
    // silently bypassing the optional cache throughout this regression.
    expect(await cache.getVersion('packages:list')).not.toBeNull();
    const first = await request(app).get('/api/packages');
    expect(first.status).toBe(200);
    expectStock(first.body.data.find((row) => row.id === pkg.id), 5, 5);
    const listQuery = jest.spyOn(SurprisePackage, 'findAndCountAll');
    const cached = await request(app).get('/api/packages');
    expect(cached.status).toBe(200);
    expect(cached.body).toEqual(first.body);
    expect(listQuery).not.toHaveBeenCalled();

    const updated = await edit(owner, pkg, { quantity: 10 });
    expect(updated.status).toBe(200);
    expectStock(updated.body.package, 10, 10);
    expectStock(await SurprisePackage.findByPk(pkg.id), 10, 10);

    const publicList = await request(app).get('/api/packages');
    expect(publicList.status).toBe(200);
    expectStock(publicList.body.data.find((row) => row.id === pkg.id), 10, 10);
    expect(listQuery).toHaveBeenCalledTimes(1);

    const ownerList = await request(app)
      .get(`/api/business-dashboard/${business.id}/packages`).set(authHeader(owner));
    expect(ownerList.status).toBe(200);
    expectStock(ownerList.body.data.find((row) => row.id === pkg.id), 10, 10);
    const detail = await request(app).get(`/api/packages/${pkg.id}`);
    expect(detail.status).toBe(200);
    expectStock(detail.body.package, 10, 10);
  });

  test.each([
    ['payment hold', 50, 'awaiting_payment', 'pending'],
    ['paid order', 0, 'pending', 'paid'],
  ])('preserves two committed units from a %s: 3/5 becomes 8/10', async (_label, discountedPrice, status, paymentStatus) => {
    const { owner, pkg } = await fixture({ discountedPrice });
    const customer = await createUser();
    const reservation = await reserve(customer, pkg, 2);
    expect(reservation.status).toBe(201);
    expect(reservation.body.order).toMatchObject({ quantity: 2, status, paymentStatus });
    expectStock(await SurprisePackage.findByPk(pkg.id), 3, 5);

    const updated = await edit(owner, pkg, { quantity: 10 });
    expect(updated.status).toBe(200);
    expectStock(updated.body.package, 8, 10);
    expectStock(await SurprisePackage.findByPk(pkg.id), 8, 10);
    expect(await Order.findByPk(reservation.body.order.id)).toMatchObject({ quantity: 2, status, paymentStatus });
  });

  test('reducing unsold stock from 5 to 3 updates both counters', async () => {
    const { owner, pkg } = await fixture();
    const updated = await edit(owner, pkg, { quantity: 3 });
    expect(updated.status).toBe(200);
    expectStock(updated.body.package, 3, 3);
    expectStock(await SurprisePackage.findByPk(pkg.id), 3, 3);
  });

  test('rejects total below committed stock and permits exactly the committed total', async () => {
    const { owner, pkg } = await fixture();
    const customer = await createUser();
    expect((await reserve(customer, pkg, 2)).status).toBe(201);

    const rejected = await edit(owner, pkg, { quantity: 1, title: 'Must roll back' });
    expect(rejected.status).toBe(400);
    expectStock(await SurprisePackage.findByPk(pkg.id), 3, 5);
    expect((await SurprisePackage.findByPk(pkg.id)).title).toBe(pkg.title);

    const atBoundary = await edit(owner, pkg, { quantity: 2 });
    expect(atBoundary.status).toBe(200);
    expectStock(atBoundary.body.package, 0, 2);
    expectStock(await SurprisePackage.findByPk(pkg.id), 0, 2);
  });

  test('refilling a sold-out package adds only the new units and restores public visibility', async () => {
    const { owner, pkg } = await fixture();
    const customer = await createUser();
    expect((await reserve(customer, pkg, 5)).status).toBe(201);
    expectStock(await SurprisePackage.findByPk(pkg.id), 0, 5);
    const empty = await request(app).get('/api/packages');
    expect(empty.status).toBe(200);
    expect(empty.body.data).toEqual([]);

    const updated = await edit(owner, pkg, { quantity: 10 });
    expect(updated.status).toBe(200);
    expectStock(updated.body.package, 5, 10);
    const publicList = await request(app).get('/api/packages');
    expect(publicList.status).toBe(200);
    expectStock(publicList.body.data.find((row) => row.id === pkg.id), 5, 10);
  });

  test('repeating the same absolute quantity does not add stock twice', async () => {
    const { owner, pkg } = await fixture();
    const customer = await createUser();
    expect((await reserve(customer, pkg, 2)).status).toBe(201);
    for (let attempt = 0; attempt < 2; attempt++) {
      const updated = await edit(owner, pkg, { quantity: 10 });
      expect(updated.status).toBe(200);
      expectStock(updated.body.package, 8, 10);
    }
    expectStock(await SurprisePackage.findByPk(pkg.id), 8, 10);
  });

  test('editing only descriptive fields leaves committed and available stock unchanged', async () => {
    const { owner, pkg } = await fixture();
    const customer = await createUser();
    expect((await reserve(customer, pkg, 2)).status).toBe(201);
    const updated = await edit(owner, pkg, { title: 'Updated title' });
    expect(updated.status).toBe(200);
    expect(updated.body.package.title).toBe('Updated title');
    expectStock(updated.body.package, 3, 5);
    expectStock(await SurprisePackage.findByPk(pkg.id), 3, 5);
  });

  test('an explicit remainingQuantity is honored instead of applying the implicit delta', async () => {
    const { owner, pkg } = await fixture();
    const updated = await edit(owner, pkg, { quantity: 10, remainingQuantity: 7 });
    expect(updated.status).toBe(200);
    expectStock(updated.body.package, 7, 10);
    const remainingOnly = await edit(owner, pkg, { remainingQuantity: 0 });
    expect(remainingOnly.status).toBe(200);
    expectStock(remainingOnly.body.package, 0, 10);
    expectStock(await SurprisePackage.findByPk(pkg.id), 0, 10);
  });

  test.each([
    { quantity: 4, remainingQuantity: 5 },
    { remainingQuantity: 6 },
    { remainingQuantity: -1 },
  ])('invalid explicit stock %j is rejected without changing either counter', async (body) => {
    const { owner, pkg } = await fixture();
    const updated = await edit(owner, pkg, body);
    expect(updated.status).toBe(400);
    expectStock(await SurprisePackage.findByPk(pkg.id), 5, 5);
  });

  test('cancelling an existing hold after refill returns only its reserved units', async () => {
    const { owner, pkg } = await fixture();
    const customer = await createUser();
    const reservation = await reserve(customer, pkg, 2);
    expect(reservation.status).toBe(201);
    expect((await edit(owner, pkg, { quantity: 10 })).status).toBe(200);
    expectStock(await SurprisePackage.findByPk(pkg.id), 8, 10);
    const cancelled = await request(app)
      .patch(`/api/orders/${reservation.body.order.id}/cancel`).set(authHeader(customer));
    expect(cancelled.status).toBe(200);
    expectStock(await SurprisePackage.findByPk(pkg.id), 10, 10);
  });

  test('a reservation committed after the initial read is preserved by the locked reload', async () => {
    const { owner, pkg } = await fixture();
    const customer = await createUser();
    const originalFind = SurprisePackage.findByPk.bind(SurprisePackage);
    let reservation;
    let intercepted = false;
    jest.spyOn(SurprisePackage, 'findByPk').mockImplementation(async (id, options) => {
      const snapshot = await originalFind(id, options);
      if (id === pkg.id && options?.include && !options.transaction && !intercepted) {
        intercepted = true;
        // The update has read 5/5 but has not acquired its row lock. Commit a
        // real reservation now, then hand that stale snapshot to the update.
        reservation = await reserve(customer, pkg, 2);
      }
      return snapshot;
    });

    const updated = await edit(owner, pkg, { quantity: 10 });
    expect(intercepted).toBe(true);
    expect(reservation.status).toBe(201);
    expect(updated.status).toBe(200);
    expectStock(updated.body.package, 8, 10);
    expectStock(await originalFind(pkg.id), 8, 10);
    expect(await Order.count({ where: { packageId: pkg.id } })).toBe(1);
  });

  test('two concurrent edits to the same total add the stock difference only once', async () => {
    const { owner, pkg } = await fixture();
    const customer = await createUser();
    expect((await reserve(customer, pkg, 2)).status).toBe(201);
    const originalFind = SurprisePackage.findByPk.bind(SurprisePackage);
    let releaseReads;
    const bothRead = new Promise((resolve) => { releaseReads = resolve; });
    let reads = 0;
    jest.spyOn(SurprisePackage, 'findByPk').mockImplementation(async (id, options) => {
      const snapshot = await originalFind(id, options);
      if (id === pkg.id && options?.include && !options.transaction) {
        reads++;
        if (reads === 2) releaseReads();
        // Both requests must see 3/5 before either obtains the update lock.
        await bothRead;
      }
      return snapshot;
    });

    try {
      const results = await Promise.all([
        edit(owner, pkg, { quantity: 10 }),
        edit(owner, pkg, { quantity: 10 }),
      ]);
      expect(reads).toBe(2);
      for (const updated of results) {
        expect(updated.status).toBe(200);
        expectStock(updated.body.package, 8, 10);
      }
      expectStock(await originalFind(pkg.id), 8, 10);
    } finally {
      releaseReads();
    }
  });
});
