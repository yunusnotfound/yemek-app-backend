jest.mock('../src/services/notificationService', () => ({ notifyOrderStatus: jest.fn().mockResolvedValue() }));
const request = require('supertest');
const app = require('../src/app');
const { Order } = require('../src/models');
const { resetDb, closeDb, createUser, createBusiness, createPackage, authHeader } = require('./helpers');

beforeEach(resetDb);
afterAll(closeDb);

async function heldOrder(user, pkg) {
  return Order.create({ userId: user.id, packageId: pkg.id, quantity: 1,
    totalPrice: 50, finalPrice: 50, pickupCode: '654321', status: 'awaiting_payment', paymentStatus: 'pending' });
}

test('owner cannot undo admin suspension of a business', async () => {
  const admin = await createUser({ role: 'admin' });
  const owner = await createUser({ role: 'business_owner' });
  const business = await createBusiness({ ownerId: owner.id });
  const suspended = await request(app).patch(`/api/admin/businesses/${business.id}/active`).set(authHeader(admin)).send({ isActive: false });
  expect(suspended.status).toBe(200);
  const revived = await request(app).put(`/api/businesses/${business.id}`).set(authHeader(owner)).send({ isActive: true });
  expect(revived.status).toBe(403);
  expect((await business.reload()).isActive).toBe(false);
});

test('owner cannot undo admin suspension of a package', async () => {
  const admin = await createUser({ role: 'admin' });
  const owner = await createUser({ role: 'business_owner' });
  const business = await createBusiness({ ownerId: owner.id });
  const pkg = await createPackage({ businessId: business.id });
  const suspended = await request(app).patch(`/api/admin/packages/${pkg.id}/active`).set(authHeader(admin)).send({ isActive: false });
  expect(suspended.status).toBe(200);
  expect((await request(app).put(`/api/packages/${pkg.id}`).set(authHeader(owner)).send({ isActive: true })).status).toBe(403);
  expect((await pkg.reload()).isActive).toBe(false);
});

test('account deletion leaves active payments and inventory intact', async () => {
  const user = await createUser();
  const pkg = await createPackage({ remainingQuantity: 4 });
  const order = await heldOrder(user, pkg);
  expect((await request(app).delete('/api/users/profile').set(authHeader(user))).status).toBe(409);
  expect((await order.reload()).status).toBe('awaiting_payment');
  expect((await pkg.reload()).remainingQuantity).toBe(4);
  expect((await user.reload()).deletedAt).toBeNull();
});

test('owner cannot delete business or package with a payment hold', async () => {
  const owner = await createUser({ role: 'business_owner' });
  const business = await createBusiness({ ownerId: owner.id });
  const pkg = await createPackage({ businessId: business.id });
  const customer = await createUser();
  await heldOrder(customer, pkg);
  expect((await request(app).delete(`/api/packages/${pkg.id}`).set(authHeader(owner))).status).toBe(409);
  expect((await request(app).delete(`/api/businesses/${business.id}`).set(authHeader(owner))).status).toBe(409);
  expect((await request(app).delete('/api/users/profile').set(authHeader(owner))).status).toBe(409);
});

test('account deletion clears the stored card wallet', async () => {
  const user = await createUser({ cardUserKey: 'synthetic-wallet-key' });
  expect((await request(app).delete('/api/users/profile').set(authHeader(user))).status).toBe(200);
  await user.reload({ paranoid: false });
  expect(user.cardUserKey).toBeNull();
  expect(user.deletedAt).toBeTruthy();
});

test('admin deletion also refuses accounts with outstanding orders', async () => {
  const admin = await createUser({ role: 'admin' });
  const user = await createUser();
  await heldOrder(user, await createPackage());
  expect((await request(app).delete(`/api/admin/users/${user.id}`).set(authHeader(admin))).status).toBe(409);
  expect((await user.reload()).deletedAt).toBeNull();
});

test('admin cannot bypass self-deletion protection through the profile endpoint', async () => {
  const admin = await createUser({ role: 'admin' });
  expect((await request(app).delete('/api/users/profile').set(authHeader(admin))).status).toBe(409);
});

test('concurrent admin demotions cannot remove the last admin', async () => {
  const first = await createUser({ role: 'admin' });
  const second = await createUser({ role: 'admin' });
  const results = await Promise.all([
    request(app).put(`/api/admin/users/${second.id}`).set(authHeader(first)).send({ role: 'customer' }),
    request(app).put(`/api/admin/users/${first.id}`).set(authHeader(second)).send({ role: 'customer' }),
  ]);
  expect(results.filter(r => r.status === 200)).toHaveLength(1);
  expect(await require('../src/models').User.count({ where: { role: 'admin' } })).toBe(1);
});

test('inactive business and expired package cannot accept new orders', async () => {
  const user = await createUser();
  const business = await createBusiness({ isActive: false });
  const pkg = await createPackage({ businessId: business.id });
  expect((await request(app).post('/api/orders').set(authHeader(user)).send({ packageId: pkg.id, quantity: 1 })).status).toBe(403);
  const expired = await createPackage({ pickupDate: '2020-01-01' });
  expect((await request(app).post('/api/orders').set(authHeader(user)).send({ packageId: expired.id, quantity: 1 })).status).toBe(400);
});

test('validated query replaces the Express 5 getter and preserves supported filters', () => {
  const { validateQuery } = require('../src/middlewares/validate');
  const { paginationSchema } = require('../src/validations/schemas');
  const req = Object.create({ get query() { return { page: '2', limit: '10', status: 'confirmed', unreadOnly: 'true', injected: 'bad' }; } });
  const next = jest.fn();
  validateQuery(paginationSchema)(req, {}, next);
  expect(next).toHaveBeenCalledTimes(1);
  expect(req.query).toEqual({ page: 2, limit: 10, status: 'confirmed', unreadOnly: 'true' });
});

test('TLS validation survives DATABASE_URL options and preserves the configured CA', async () => {
  const { enforceDatabaseTls, isDatabaseTlsRequired } = require('../src/config/databaseTls');
  const { Sequelize } = require('sequelize');
  const old = process.env.DB_CA_CERT;
  const oldUrl = process.env.DATABASE_URL;
  process.env.DB_CA_CERT = 'test-ca';
  const config = { dialectOptions: { ssl: { rejectUnauthorized: false } } };
  enforceDatabaseTls(config);
  expect(config.dialectOptions.ssl).toEqual({ rejectUnauthorized: true, ca: 'test-ca' });
  process.env.DATABASE_URL = 'postgres://test:test@localhost/test?sslmode=no-verify';
  expect(isDatabaseTlsRequired()).toBe(true);
  // Exercise Sequelize's actual URL merge, without opening a connection.
  const instance = new Sequelize(process.env.DATABASE_URL, { logging: false, hooks: { beforeConnect: enforceDatabaseTls } });
  await instance.runHooks('beforeConnect', instance.config);
  expect(instance.config.dialectOptions.ssl.rejectUnauthorized).toBe(true);
  expect(instance.config.dialectOptions.ssl.ca).toBe('test-ca');
  await instance.close();
  if (old === undefined) delete process.env.DB_CA_CERT; else process.env.DB_CA_CERT = old;
  if (oldUrl === undefined) delete process.env.DATABASE_URL; else process.env.DATABASE_URL = oldUrl;
});

test('logging redacts nested credentials and card fields without losing diagnostics', () => {
  const { redact } = require('../src/utils/redact');
  const input = { action: 'checkout', card: { cardNumber: '4111111111111111', cvc: '123' },
    nested: { refreshToken: 'secret-token', password: 'secret-password' }, message: 'Bearer secret-access' };
  const output = JSON.stringify(redact(input));
  expect(output).toContain('checkout');
  for (const secret of ['4111111111111111', '123', 'secret-token', 'secret-password', 'secret-access']) {
    expect(output).not.toContain(secret);
  }
  expect(input.nested.password).toBe('secret-password');
});
