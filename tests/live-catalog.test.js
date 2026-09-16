const request = require('supertest');
const app = require('../src/app');
const cache = require('../src/services/cacheService');
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
  expect(noPackages.map[0].packageCount).toBe(0);
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
  expect(live.map[0].packageCount).toBe(0);
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
