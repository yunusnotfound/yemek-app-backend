jest.mock('../src/services/notificationService', () => ({
  notifyNewOrder: jest.fn().mockResolvedValue(),
  notifyOrderStatus: jest.fn().mockResolvedValue(),
  createNotification: jest.fn().mockResolvedValue(),
}));

const request = require('supertest');
const app = require('../src/app');
const { sequelize } = require('../src/models');
const cache = require('../src/services/cacheService');
const coalesce = require('../src/services/requestCoalescer');
const { resetDb, closeDb, createUser, createBusiness, createPackage, createCoupon, authHeader } = require('./helpers');

beforeEach(async () => {
  await resetDb();
  // Optional cache commands intentionally skip the first connection attempt.
  // These tests need a ready cache to distinguish real hits from safe bypasses.
  for (let attempt = 0; attempt < 200; attempt++) {
    if (await cache.getVersion('packages:list') != null) return;
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error('The isolated Redis cache did not become ready');
});
afterEach(() => jest.restoreAllMocks());
afterAll(closeDb);

const endpoints = [
  { name: 'businesses', path: '/api/businesses', rows: (body) => body.data, itemId: (pkg) => pkg.businessId, business: (row) => row },
  { name: 'packages', path: '/api/packages', rows: (body) => body.data, itemId: (pkg) => pkg.id, business: (row) => row.business },
  { name: 'map', path: '/api/maps/nearby', rows: (body) => body.businesses, itemId: (pkg) => pkg.businessId, business: (row) => row },
];
const getList = (endpoint, user, { lat = 41, lng = 29, radius = 0.5 } = {}) => request(app)
  .get(`${endpoint.path}?lat=${lat}&lng=${lng}&radius=${radius}`).set(authHeader(user));

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

const publicQueries = (queries) => queries.filter((sql) => !sql.includes('FROM "Users"'));

test.each(endpoints)('$name preserves 0.5 km membership between coordinates previously rounded to the same key', async (endpoint) => {
  const user = await createUser();
  const business = await createBusiness({ latitude: 41.0085, longitude: 29.0001 });
  const pkg = await createPackage({ businessId: business.id });
  const a = { lat: 41.0001, lng: 29.0001, radius: 0.5 };
  const b = { lat: 41.0049, lng: 29.0001, radius: 0.5 };
  expect(a.lat.toFixed(2)).toBe(b.lat.toFixed(2));

  const outside = await getList(endpoint, user, a);
  expect(outside.status).toBe(200);
  expect(endpoint.rows(outside.body)).toEqual([]);
  const inside = await getList(endpoint, user, b);
  expect(inside.status).toBe(200);
  expect(endpoint.rows(inside.body).map((item) => item.id)).toEqual([endpoint.itemId(pkg)]);
  expect(Number(endpoint.business(endpoint.rows(inside.body)[0]).distance)).toBeLessThan(0.5);

  const { value: repeated, queries } = await recordSql(() => Promise.all([
    getList(endpoint, user, a), getList(endpoint, user, b),
  ]));
  expect(repeated.map((response) => response.body)).toEqual([outside.body, inside.body]);
  expect(publicQueries(queries)).toHaveLength(0);
});

test('map cache reflects reservation stock reduction and cancellation restoration immediately', async () => {
  const user = await createUser();
  const pkg = await createPackage({ discountedPrice: 0, quantity: 1, remainingQuantity: 1 });
  const endpoint = endpoints[2];
  const before = await getList(endpoint, user);
  expect(before.status).toBe(200);
  expect(before.body.businesses.find((business) => business.id === pkg.businessId).packageCount).toBe(1);

  const order = await request(app).post('/api/orders').set(authHeader(user)).send({ packageId: pkg.id, quantity: 1 });
  expect(order.status).toBe(201);
  const reserved = await getList(endpoint, user);
  expect(reserved.status).toBe(200);
  expect(reserved.body.businesses.find((business) => business.id === pkg.businessId).packageCount).toBe(0);

  const cancelled = await request(app).patch(`/api/orders/${order.body.order.id}/cancel`).set(authHeader(user));
  expect(cancelled.status).toBe(200);
  const restored = await getList(endpoint, user);
  expect(restored.body.businesses.find((business) => business.id === pkg.businessId).packageCount).toBe(1);
});

test.each(endpoints)('$name shares identical concurrent cold reads and preserves public field filtering', async (endpoint) => {
  const user = await createUser();
  const business = await createBusiness({ iban: 'PRIVATE-IBAN', identityNumber: 'PRIVATE-IDENTITY', taxNumber: 'PRIVATE-TAX' });
  const pkg = await createPackage({ businessId: business.id });
  const { value: responses, queries } = await recordSql(() => Promise.all(
    Array.from({ length: 20 }, () => getList(endpoint, user)),
  ));
  for (const response of responses) {
    expect(response.status).toBe(200);
    expect(endpoint.rows(response.body).map((item) => item.id)).toEqual([endpoint.itemId(pkg)]);
    expect(response.body).toEqual(responses[0].body);
    const publicBusiness = endpoint.business(endpoint.rows(response.body)[0]);
    for (const field of ['iban', 'identityNumber', 'taxNumber', 'subMerchantKey']) {
      expect(publicBusiness).not.toHaveProperty(field);
    }
  }
  // A loader normally needs 2 queries. Allow a second wave of requests whose
  // initial cache miss raced the first completed loader, but never 20 loaders.
  expect(publicQueries(queries).length).toBeGreaterThan(0);
  expect(publicQueries(queries).length).toBeLessThanOrEqual(4);
});

test('concurrent campaign lists keep their scopes separate from each other and public cached data', async () => {
  const user = await createUser();
  const otherUser = await createUser();
  const first = await createPackage();
  const second = await createPackage();
  const couponA = await createCoupon({ isDiscoverable: true, businessIds: [first.businessId] });
  const couponB = await createCoupon({ isDiscoverable: true, businessIds: [second.businessId] });
  const campaignList = (coupon, buyer) => request(app).get(`/api/coupons/${coupon.id}/packages`).set(authHeader(buyer));
  const [a, b, publicList] = await Promise.all([
    campaignList(couponA, user), campaignList(couponB, otherUser), request(app).get('/api/packages'),
  ]);
  expect([a.status, b.status, publicList.status]).toEqual([200, 200, 200]);
  expect(a.body.data.map((pkg) => pkg.id)).toEqual([first.id]);
  expect(b.body.data.map((pkg) => pkg.id)).toEqual([second.id]);
  expect(publicList.body.data.map((pkg) => pkg.id).sort()).toEqual([first.id, second.id].sort());
  const [cachedA, cachedB, cachedPublic] = await Promise.all([
    campaignList(couponA, user), campaignList(couponB, otherUser), request(app).get('/api/packages'),
  ]);
  expect(cachedA.body).toEqual(a.body);
  expect(cachedB.body).toEqual(b.body);
  expect(cachedPublic.body).toEqual(publicList.body);
});

test('coalescer shares only pending work and releases settled values', async () => {
  let release;
  const gate = new Promise((resolve) => { release = resolve; });
  const value = { stock: 5 };
  const load = jest.fn(async () => { await gate; return value; });
  const pending = Array.from({ length: 50 }, () => coalesce('test:shared', load));
  await Promise.resolve();
  expect(load).toHaveBeenCalledTimes(1);
  release();
  const results = await Promise.all(pending);
  expect(results.every((result) => result === value)).toBe(true);
  const fresh = jest.fn().mockResolvedValue({ stock: 0 });
  expect(await coalesce('test:shared', fresh)).toEqual({ stock: 0 });
  expect(fresh).toHaveBeenCalledTimes(1);
});

test('coalescer cleans failed and synchronously throwing loads so retries can recover', async () => {
  const failure = new Error('temporary query failure');
  const load = jest.fn().mockRejectedValue(failure);
  const results = await Promise.allSettled(Array.from({ length: 20 }, () => coalesce('test:failure', load)));
  expect(load).toHaveBeenCalledTimes(1);
  expect(results.every((result) => result.status === 'rejected' && result.reason === failure)).toBe(true);
  await expect(coalesce('test:failure', () => { throw failure; })).rejects.toBe(failure);
  await expect(coalesce('test:failure', () => 'recovered')).resolves.toBe('recovered');
});

test('null keys bypass shared work for request-specific data and cache unavailability', async () => {
  const results = await Promise.all(Array.from({ length: 20 }, (_, userId) =>
    coalesce(null, async () => ({ userId })),
  ));
  expect(results.map((value) => value.userId)).toEqual(Array.from({ length: 20 }, (_, index) => index));
});
