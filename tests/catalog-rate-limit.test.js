// Exercise real app middleware without hitting database-backed controllers.
jest.mock('../src/routes', () => {
  const router = require('express').Router();
  router.use((req, res) => res.json({ ok: true }));
  return router;
});

const request = require('supertest');
const jwt = require('jsonwebtoken');
const { randomUUID } = require('crypto');
const savedEnvironment = process.env.NODE_ENV;
process.env.NODE_ENV = 'production';
const app = require('../src/app');
process.env.NODE_ENV = savedEnvironment;

// Reuse one listener for the burst test instead of opening/closing hundreds of
// ephemeral HTTP servers, which can reuse a port while a socket is closing.
let server;
beforeAll(() => new Promise((resolve) => {
  server = app.listen(0, '127.0.0.1', resolve);
}));
afterAll(() => new Promise((resolve, reject) => {
  server.close((error) => error ? reject(error) : resolve());
}));

const customerToken = () => jwt.sign({ id: randomUUID(), role: 'customer' }, process.env.JWT_SECRET, {
  algorithm: 'HS256', expiresIn: '15m',
});
const businessId = '00000000-0000-4000-8000-000000000001';
const catalogPaths = [
  '/api/businesses?lat=41&lng=29&radius=5',
  `/api/businesses/${businessId}`,
  '/api/packages/',
  `/api/packages/${businessId}`,
  '/api/maps/nearby?lat=41&lng=29&radius=5',
];
const get = (path, token) => request(server).get(path).set('Authorization', `Bearer ${token}`);

test('foreground catalog polling has a shared 300-read budget and still rejects excessive requests', async () => {
  const token = customerToken();
  // A selected map card polls three endpoints every 15s: 180 calls / 15min.
  for (let index = 0; index < 300; index++) {
    const response = await get(catalogPaths[index % catalogPaths.length], token);
    expect(response.status).toBe(200);
    expect(response.headers['ratelimit-limit']).toBe('300');
    expect(Number(response.headers['ratelimit-remaining'])).toBe(299 - index);
  }
  const exceeded = await get(catalogPaths[0], token);
  expect(exceeded.status).toBe(429);
  expect(Number(exceeded.headers['retry-after'])).toBeGreaterThan(0);
  // A user's read budget cannot consume their order/write budget.
  const order = await request(server).post('/api/orders').set('Authorization', `Bearer ${token}`).send({});
  expect(order.status).toBe(200);
  expect(order.headers['ratelimit-limit']).toBe('100');
  expect(order.headers['ratelimit-remaining']).toBe('99');
  expect((await get(catalogPaths[0], customerToken())).status).toBe(200);
});

test('general requests retain their 100-request cap and do not consume catalog reads', async () => {
  const token = customerToken();
  for (let index = 0; index < 100; index++) {
    expect((await get('/api/orders', token)).status).toBe(200);
  }
  expect((await get('/api/orders', token)).status).toBe(429);
  const catalog = await get('/api/packages', token);
  expect(catalog.status).toBe(200);
  expect(catalog.headers['ratelimit-remaining']).toBe('299');
});

test.each([
  ['post', '/api/businesses'],
  ['put', `/api/businesses/${businessId}`],
  ['delete', `/api/businesses/${businessId}`],
  ['post', '/api/packages'],
  ['put', `/api/packages/${businessId}`],
  ['delete', `/api/packages/${businessId}`],
  ['head', '/api/packages'],
  ['get', '/api/maps/directions'],
  ['get', `/api/businesses/${businessId}/private`],
  ['get', '/api/packages/not-a-uuid'],
])('%s %s keeps the general budget', async (method, path) => {
  const response = await request(server)[method](path).set('Authorization', `Bearer ${customerToken()}`);
  expect(response.status).toBe(200);
  expect(response.headers['ratelimit-limit']).toBe('100');
});

test.each([
  ['/api/auth/login', '20'],
  ['/api/cards', '20'],
  ['/api/business-dashboard', '200'],
  ['/api/admin/businesses', '300'],
  ['/api/payments/status', '600'],
])('%s keeps its existing dedicated budget', async (path, limit) => {
  const response = await request(server).post(path).set('Authorization', `Bearer ${customerToken()}`).send({});
  expect(response.status).toBe(200);
  expect(response.headers['ratelimit-limit']).toBe(limit);
});

test('anonymous and invalid-token catalog requests share the IP budget', async () => {
  const anonymous = await request(server).get('/api/packages');
  expect(anonymous.headers['ratelimit-remaining']).toBe('299');
  const invalid = await get('/api/packages', 'invalid-token');
  expect(invalid.headers['ratelimit-remaining']).toBe('298');
});
