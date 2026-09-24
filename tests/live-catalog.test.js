const request = require('supertest');
const app = require('../src/app');
const cache = require('../src/services/cacheService');
const { Favorite } = require('../src/models');
const {
  resetDb, closeDb, createUser, createCategory, createBusiness, createPackage, authHeader,
} = require('./helpers');

beforeEach(async () => {
  await resetDb();
  // Exercise invalidation against real cache hits, not just the DB fallback.
  for (let attempt = 0; attempt < 200; attempt++) {
    if (await cache.getVersion('packages:list') != null) return;
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error('The isolated catalog Redis did not become ready');
});
afterEach(() => jest.restoreAllMocks());
afterAll(closeDb);

async function catalog(user) {
  const [businesses, packages, map] = await Promise.all([
    request(app).get('/api/businesses?lat=41&lng=29&radius=5'),
    request(app).get('/api/packages?lat=41&lng=29&radius=5'),
    request(app).get('/api/maps/nearby?lat=41&lng=29&radius=5').set(authHeader(user)),
  ]);
  expect([businesses.status, packages.status, map.status]).toEqual([200, 200, 200]);
  return { businesses: businesses.body.data, packages: packages.body.data, map: map.body.businesses };
}

test('an empty catalog stays empty in public lists and map without sample businesses', async () => {
  const customer = await createUser();
  const empty = { businesses: [], packages: [], map: [] };
  expect(await catalog(customer)).toEqual(empty);
  expect(await catalog(customer)).toEqual(empty);
});

test('panel creation, approval, edits and deactivation reach cached customer lists and map', async () => {
  const owner = await createUser({ role: 'business_owner' });
  const admin = await createUser({ role: 'admin' });
  const customer = await createUser();
  const category = await createCategory();
  const createdBusiness = await request(app).post('/api/businesses').set(authHeader(owner)).send({
    name: 'Panel İşletmesi', address: 'İşletme adresi', city: 'İstanbul', district: 'Kadıköy',
    latitude: 41, longitude: 29, categoryId: category.id,
  });
  expect(createdBusiness.status).toBe(201);
  const businessId = createdBusiness.body.business.id;
  const pickupDate = new Date(Date.now() + 3 * 86400000).toISOString().slice(0, 10);
  const createdPackage = await request(app).post('/api/packages').set(authHeader(owner)).send({
    businessId, title: 'Panel Paketi', originalPrice: 300, discountedPrice: 150, quantity: 5,
    pickupDate, pickupStart: '10:00:00', pickupEnd: '20:00:00',
  });
  expect(createdPackage.status).toBe(201);
  const packageId = createdPackage.body.package.id;

  // Publishing requires administrator approval even when packages already exist.
  expect(await catalog(customer)).toEqual({ businesses: [], packages: [], map: [] });
  expect((await request(app).patch(`/api/admin/businesses/${businessId}/approve`)
    .set(authHeader(admin))).status).toBe(200);
  const published = await catalog(customer);
  expect(published.businesses.map((business) => business.id)).toEqual([businessId]);
  expect(published.packages.map((pkg) => pkg.id)).toEqual([packageId]);
  expect(published.map.map((business) => [business.id, business.packageCount])).toEqual([[businessId, 1]]);
  expect(await catalog(customer)).toEqual(published);

  expect((await request(app).put(`/api/businesses/${businessId}`).set(authHeader(owner))
    .send({ name: 'Güncel Panel İşletmesi', latitude: 41.001 })).status).toBe(200);
  expect((await request(app).put(`/api/packages/${packageId}`).set(authHeader(owner))
    .send({ title: 'Güncel Panel Paketi', discountedPrice: 125 })).status).toBe(200);
  const updated = await catalog(customer);
  for (const business of [updated.businesses[0], updated.packages[0].business, updated.map[0]]) {
    expect(business.name).toBe('Güncel Panel İşletmesi');
    expect(Number(business.latitude)).toBe(41.001);
  }
  expect(updated.packages[0].title).toBe('Güncel Panel Paketi');
  expect(Number(updated.packages[0].discountedPrice)).toBe(125);

  expect((await request(app).put(`/api/packages/${packageId}`).set(authHeader(owner))
    .send({ isActive: false })).status).toBe(200);
  const noPackages = await catalog(customer);
  expect(noPackages.packages).toEqual([]);
  expect(noPackages.map).toEqual([]);
  expect((await request(app).get(`/api/packages/${packageId}`)).status).toBe(404);
  expect((await request(app).get(`/api/businesses/${businessId}`)).body.business.packages).toEqual([]);

  expect((await request(app).put(`/api/businesses/${businessId}`).set(authHeader(owner))
    .send({ isActive: false })).status).toBe(200);
  expect(await catalog(customer)).toEqual({ businesses: [], packages: [], map: [] });
  expect((await request(app).get(`/api/businesses/${businessId}`)).status).toBe(404);
});

test('suspended businesses stay hidden even if their active and approval flags are set', async () => {
  const customer = await createUser();
  const business = await createBusiness({ isActive: true, isApproved: true, isSuspended: true });
  const pkg = await createPackage({ businessId: business.id });
  expect(await catalog(customer)).toEqual({ businesses: [], packages: [], map: [] });
  expect((await request(app).get(`/api/businesses/${business.id}`)).status).toBe(404);
  expect((await request(app).get(`/api/packages/${pkg.id}`)).status).toBe(404);
});

test('suspended packages do not appear in map counts, business details or direct package links', async () => {
  const customer = await createUser();
  const business = await createBusiness();
  const hidden = await createPackage({ businessId: business.id, isActive: true, isSuspended: true });
  const live = await catalog(customer);
  expect(live.businesses.map((item) => item.id)).toEqual([business.id]);
  expect(live.packages).toEqual([]);
  expect(live.map).toEqual([]);
  expect((await request(app).get(`/api/businesses/${business.id}`)).body.business.packages).toEqual([]);
  expect((await request(app).get(`/api/packages/${hidden.id}`)).status).toBe(404);
});

test('business detail, package list and map count omit expired packages while retaining current ones', async () => {
  const customer = await createUser();
  const business = await createBusiness();
  await createPackage({ businessId: business.id, pickupDate: '2020-01-01' });
  const available = await createPackage({ businessId: business.id });
  const live = await catalog(customer);
  expect(live.packages.map((pkg) => pkg.id)).toEqual([available.id]);
  expect(live.map[0].packageCount).toBe(1);
  const detail = await request(app).get(`/api/businesses/${business.id}`);
  expect(detail.status).toBe(200);
  expect(detail.body.business.packages.map((pkg) => pkg.id)).toEqual([available.id]);
});

// Persist real Istanbul wall-clock values; PostgreSQL and Redis keep their real
// clocks too, so these regressions cover expiry without global Date mocks.
const istanbulParts = (timestamp) => {
  const local = new Date(timestamp + 3 * 60 * 60 * 1000).toISOString();
  return { date: local.slice(0, 10), time: local.slice(11, 19) };
};
const pickupWindowEndingAt = (timestamp, { overnight = false } = {}) => {
  const end = istanbulParts(timestamp);
  const start = overnight
    ? { date: istanbulParts(timestamp - 86400000).date, time: '23:59:59' }
    : istanbulParts(timestamp - 60 * 60 * 1000);
  return { pickupDate: start.date, pickupStart: start.time, pickupEnd: end.time };
};
const savedFavorites = async (customer) => {
  const response = await request(app).get('/api/favorites').set(authHeader(customer));
  expect(response.status).toBe(200);
  return response.body;
};

test('same-day expiry removes a business from map while preserving its favorite for its next live package', async () => {
  const customer = await createUser();
  const owner = await createUser({ role: 'business_owner' });
  const business = await createBusiness({ ownerId: owner.id });
  await createPackage({ businessId: business.id, ...pickupWindowEndingAt(Date.now() - 1000) });
  const saved = await Favorite.create({ userId: customer.id, businessId: business.id });

  const expired = await catalog(customer);
  expect(expired.packages).toEqual([]);
  expect(expired.map).toEqual([]);
  expect((await request(app).get(`/api/businesses/${business.id}`)).body.business.packages).toEqual([]);
  const favorites = await savedFavorites(customer);
  expect(favorites.data.map((favorite) => favorite.id)).toEqual([saved.id]);
  expect(favorites.data[0].business.packages).toEqual([]);
  expect(await Favorite.count({ where: { userId: customer.id, businessId: business.id } })).toBe(1);

  const created = await request(app).post('/api/packages').set(authHeader(owner)).send({
    businessId: business.id, title: 'Yeni Canlı Paket', originalPrice: 200, discountedPrice: 100, quantity: 3,
    ...pickupWindowEndingAt(Date.now() + 86400000),
  });
  expect(created.status).toBe(201);
  const live = await catalog(customer);
  expect(live.map.map((item) => item.id)).toEqual([business.id]);
  expect(live.packages.map((pkg) => pkg.id)).toEqual([created.body.package.id]);
  const returned = await savedFavorites(customer);
  expect(returned.data[0].id).toBe(saved.id);
  expect(returned.data[0].business.packages.map((pkg) => pkg.id)).toEqual([created.body.package.id]);
});

test('mixed package states expose only live package metadata in map, favorites and business detail', async () => {
  const customer = await createUser();
  const business = await createBusiness();
  await Favorite.create({ userId: customer.id, businessId: business.id });
  await createPackage({ businessId: business.id, ...pickupWindowEndingAt(Date.now() - 1000) });
  await createPackage({ businessId: business.id, remainingQuantity: 0 });
  await createPackage({ businessId: business.id, isActive: false });
  await createPackage({ businessId: business.id, isSuspended: true });
  const live = await createPackage({ businessId: business.id });
  const listed = await catalog(customer);
  expect(listed.packages.map((pkg) => pkg.id)).toEqual([live.id]);
  expect(listed.map[0].packageCount).toBe(1);
  expect(listed.map[0].packages.map((pkg) => pkg.id)).toEqual([live.id]);
  const favorites = await savedFavorites(customer);
  expect(favorites.pagination.total).toBe(1);
  expect(favorites.data[0].business.packages.map((pkg) => pkg.id)).toEqual([live.id]);
  const detail = await request(app).get(`/api/businesses/${business.id}`);
  expect(detail.body.business.packages.map((pkg) => pkg.id)).toEqual([live.id]);
});

test('overnight pickup stays visible until its next-day end and hides after that end', async () => {
  const customer = await createUser();
  const business = await createBusiness();
  await Favorite.create({ userId: customer.id, businessId: business.id });
  await createPackage({ businessId: business.id, ...pickupWindowEndingAt(Date.now() - 1000, { overnight: true }) });
  const live = await createPackage({
    businessId: business.id, ...pickupWindowEndingAt(Date.now() + 60000, { overnight: true }),
  });
  const listed = await catalog(customer);
  expect(listed.packages.map((pkg) => pkg.id)).toEqual([live.id]);
  expect(listed.map[0].packageCount).toBe(1);
  const hasStarted = new Date(`${live.pickupDate}T${live.pickupStart}+03:00`).getTime() <= Date.now();
  expect(listed.map[0].availableNow).toBe(hasStarted);
  expect(listed.map[0].packages.map((pkg) => pkg.id)).toEqual([live.id]);
  expect((await savedFavorites(customer)).data[0].business.packages.map((pkg) => pkg.id)).toEqual([live.id]);
  const detail = await request(app).get(`/api/businesses/${business.id}`);
  expect(detail.body.business.packages.map((pkg) => pkg.id)).toEqual([live.id]);
});

test('warmed package and map caches stop exposing a package at its real pickup deadline without writes', async () => {
  const customer = await createUser();
  const business = await createBusiness();
  await Favorite.create({ userId: customer.id, businessId: business.id });
  const expiresAt = Math.ceil(Date.now() / 1000) * 1000 + 2000;
  const pkg = await createPackage({ businessId: business.id, ...pickupWindowEndingAt(expiresAt) });
  const reads = jest.spyOn(cache, 'get');
  const before = await catalog(customer);
  expect(before.packages.map((item) => item.id)).toEqual([pkg.id]);
  expect(before.map[0].packageCount).toBe(1);
  expect(await catalog(customer)).toEqual(before);
  const values = await Promise.all(reads.mock.results.map((result) => result.value));
  for (const namespace of ['packages:list:', 'maps:nearby:']) {
    expect(reads.mock.calls.some(([key], index) => key?.startsWith(namespace) && values[index] != null)).toBe(true);
  }
  expect(Date.now()).toBeLessThan(expiresAt);
  await new Promise((resolve) => setTimeout(resolve, Math.max(0, expiresAt - Date.now()) + 30));
  const after = await catalog(customer);
  expect(after.packages).toEqual([]);
  expect(after.map).toEqual([]);
  const detail = await request(app).get(`/api/businesses/${business.id}`);
  expect(detail.body.business.packages).toEqual([]);
  expect((await savedFavorites(customer)).data[0].business.packages).toEqual([]);
  expect(await Favorite.count({ where: { userId: customer.id, businessId: business.id } })).toBe(1);
});

test.each([
  { isActive: false }, { isApproved: false }, { isSuspended: true },
])('favorites hide non-public businesses without deleting the saved relation (%j)', async (moderation) => {
  const customer = await createUser();
  const business = await createBusiness(moderation);
  await createPackage({ businessId: business.id });
  await Favorite.create({ userId: customer.id, businessId: business.id });
  expect((await savedFavorites(customer)).data).toEqual([]);
  expect(await Favorite.count({ where: { userId: customer.id, businessId: business.id } })).toBe(1);
});
