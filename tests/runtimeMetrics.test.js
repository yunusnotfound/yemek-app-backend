jest.mock('../src/models', () => ({ User: { findByPk: jest.fn() } }));
jest.mock('../src/controllers/adminController', () => new Proxy({}, { get: () => (_req, res) => res.sendStatus(204) }));
jest.mock('../src/controllers/categoryController', () => new Proxy({}, { get: () => (_req, res) => res.sendStatus(204) }));

const { EventEmitter } = require('node:events');
const { execFileSync } = require('node:child_process');
const express = require('express');
const cors = require('cors');
const { rateLimit } = require('express-rate-limit');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const runtimeMetrics = require('../src/services/runtimeMetrics');
const { createRuntimeMetrics } = runtimeMetrics;
const { User } = require('../src/models');
const instances = [];

function setup(options = {}) {
  let time = 0;
  const histogram = { enable: jest.fn(), disable: jest.fn(), count: 1, percentile: () => 2_000_000 };
  const metrics = createRuntimeMetrics({
    now: () => time,
    wallNow: () => Date.UTC(2026, 8, 24) + time,
    processInfo: {
      uptime: () => 4 + time / 1000,
      version: 'v24.0.0',
      memoryUsage: () => ({ heapUsed: 100, heapTotal: 200, rss: 300 }),
    },
    histogram,
    ...options,
  });
  instances.push(metrics);
  const advance = ms => { time += ms; };
  function begin({ method = 'GET', pathname = '/api/orders/private-id', template = '/:id', base = '/api/orders', headers = {}, user } = {}) {
    const req = Object.assign(new EventEmitter(), {
      method, path: pathname, baseUrl: base, route: template === null ? undefined : { path: template },
      get: name => headers[name], user,
    });
    const res = Object.assign(new EventEmitter(), { statusCode: 200, writableFinished: false });
    const next = jest.fn();
    metrics.middleware(req, res, next);
    expect(next).toHaveBeenCalledTimes(1);
    return {
      req, res,
      finish(status = 200, duration = 10) {
        advance(duration);
        res.statusCode = status;
        res.writableFinished = true;
        res.emit('finish');
        res.emit('close');
      },
    };
  }
  return { metrics, begin, advance, histogram };
}

afterEach(() => {
  for (const metrics of instances.splice(0)) metrics.close();
  jest.clearAllMocks();
});
afterAll(() => runtimeMetrics.close());

test('rolling status, latency and RPM use the observed window and expire at 15 minutes', () => {
  const { metrics, begin, advance } = setup();
  expect(metrics.snapshot()).toMatchObject({ requests: 0, p50Ms: null, p95Ms: null, errorRatePercent: null });
  begin().finish(200, 10);
  begin().finish(302, 20);
  begin().finish(429, 30);
  begin().finish(503, 40);
  advance(59_900);
  expect(metrics.snapshot()).toMatchObject({
    requests: 4, windowSeconds: 60, requestsPerMinute: 4,
    statusCounts: { success: 2, clientError: 1, serverError: 1 },
    errorRatePercent: 25, p50Ms: 20, p95Ms: 40, maxMs: 40,
    eventLoopP95Ms: 2, eventLoopWindowSeconds: 60,
    heapUsedBytes: 100, heapTotalBytes: 200, rssBytes: 300, nodeVersion: 'v24.0.0', uptimeSeconds: 64,
  });
  advance(840_100);
  expect(metrics.snapshot()).toMatchObject({
    requests: 0, windowSeconds: 900, requestsPerMinute: 0,
    errorRatePercent: null, p50Ms: null, p95Ms: null, maxMs: null,
    statusCounts: { success: 0, clientError: 0, serverError: 0 }, slowRoutes: [], droppedSamples: 0,
  });
});

test('route templates combine with fixed mounts without retaining IDs, email, query or token values', () => {
  const { metrics, begin } = setup();
  for (let index = 0; index < 100; index++) {
    begin({ pathname: `/api/orders/private-${index}?email=private@example.test&token=secret-token`, base: index % 2 ? '' : '/api/orders' }).finish();
    begin({ pathname: `/api/unknown/private-${index}`, template: null }).finish(404);
  }
  // Even a dynamic/unknown mount cannot turn into a raw route label.
  begin({ pathname: '/api/private@example.test/token-secret', base: '/api/private@example.test', template: '/:token' }).finish();
  begin({ template: '/private@example.test' }).finish();
  const snapshot = metrics.snapshot();
  expect(snapshot.slowRoutes.find(route => route.route === '/api/orders/:id')).toMatchObject({ requests: 100 });
  expect(snapshot.slowRoutes).toHaveLength(3);
  expect(JSON.stringify(snapshot)).not.toMatch(/private-|private@|secret-token|token-secret|email=/);
});

test('buffer capacity is hard capped and dropping old samples reports the retained observation window', () => {
  const { metrics, begin } = setup({ maxSamples: 2 });
  begin().finish(500, 1000);
  begin().finish(201, 1000);
  begin().finish(202, 1000);
  expect(metrics.snapshot()).toMatchObject({
    requests: 2, droppedSamples: 1, windowSeconds: 2, requestsPerMinute: 60,
    statusCounts: { success: 2, clientError: 0, serverError: 0 },
  });
  const capped = setup({ maxSamples: 100_000 });
  for (let index = 0; index < 10_001; index++) capped.begin().finish(200, 0);
  expect(capped.metrics.snapshot()).toMatchObject({ requests: 10_000, droppedSamples: 1, windowSeconds: 1 });
});

test('finish and aborted connections count once and always release in-flight requests', () => {
  const { metrics, begin, advance } = setup();
  const aborted = begin();
  const completed = begin();
  expect(metrics.snapshot().inFlight).toBe(2);
  advance(12);
  aborted.req.emit('aborted');
  aborted.res.emit('close');
  aborted.res.emit('finish');
  completed.finish(500, 8);
  expect(metrics.snapshot()).toMatchObject({
    inFlight: 0, requests: 2, statusCounts: { success: 0, clientError: 1, serverError: 1 }, errorRatePercent: 50,
  });
  expect(aborted.res.listenerCount('finish')).toBe(0);
  expect(aborted.req.listenerCount('aborted')).toBe(0);
});

test('only API traffic is counted and monitoring profile exemption requires the exact admin read', () => {
  const { metrics, begin } = setup();
  for (const pathname of ['/page', '/api-docs', '/uploads/image.png', '/api/health', '/api/admin/dashboard', '/api/admin/settlement/summary', '/api/admin/orders', '/api/admin/operations/runtime']) {
    begin({ pathname }).finish();
  }
  const probe = { pathname: '/api/users/profile', template: '/profile', base: '/api/users', headers: { 'x-operations-probe': '1' } };
  begin({ ...probe, user: { role: 'admin' } }).finish();
  expect(metrics.snapshot()).toMatchObject({ requests: 0, inFlight: 0 });
  begin({ ...probe, user: { role: 'customer' } }).finish();
  begin({ ...probe, user: { role: 'admin' } }).finish(500);
  begin({ ...probe, pathname: '/api/users/other', user: { role: 'admin' } }).finish();
  begin({ ...probe, method: 'POST', user: { role: 'admin' } }).finish();
  begin({ ...probe, user: undefined }).finish(401);
  begin({ pathname: '/API/ORDERS/private-id' }).finish();
  expect(metrics.snapshot()).toMatchObject({ requests: 6, inFlight: 0 });
});

test('early middleware observes CORS, rate-limit, JSON-parser and handler failures', async () => {
  const { metrics } = setup();
  const app = express();
  app.use(metrics.middleware);
  app.use(cors({ origin: (origin, callback) => callback(origin === 'https://blocked.example' ? Object.assign(new Error('blocked'), { status: 403 }) : null, true) }));
  app.use('/api/limited', rateLimit({ windowMs: 60_000, limit: 1, standardHeaders: true, legacyHeaders: false }));
  app.use(express.json());
  app.get('/api/limited', (_req, res) => res.sendStatus(200));
  app.post('/api/body', (_req, res) => res.sendStatus(200));
  app.get('/api/error/:id', (_req, _res, next) => next(Object.assign(new Error('handler failed'), { status: 503 })));
  app.use((error, _req, res, _next) => res.sendStatus(error.status || 500));
  await request(app).get('/api/limited').expect(200);
  await request(app).get('/api/limited').expect(429);
  await request(app).get('/api/orders/private-user').set('Origin', 'https://blocked.example').expect(403);
  await request(app).post('/api/body').set('Content-Type', 'application/json').send('{broken').expect(400);
  await request(app).get('/api/error/private-id').expect(503);
  expect(metrics.snapshot()).toMatchObject({ requests: 5, statusCounts: { success: 1, clientError: 3, serverError: 1 }, errorRatePercent: 20 });
  expect(JSON.stringify(metrics.snapshot().slowRoutes)).not.toContain('private-id');
});

test('runtime endpoint retains the actual admin router authentication and role gate', async () => {
  const app = express();
  app.use('/api/admin', require('../src/routes/admin'));
  const endpoint = '/api/admin/operations/runtime';
  await request(app).get(endpoint).expect(401);
  const token = jwt.sign({ id: 'test-user', version: 0 }, process.env.JWT_SECRET);
  User.findByPk.mockResolvedValue({ id: 'test-user', authVersion: 0, isEmailVerified: true, role: 'customer' });
  await request(app).get(endpoint).set('Authorization', `Bearer ${token}`).expect(403);
  User.findByPk.mockResolvedValue({ id: 'test-user', authVersion: 0, isEmailVerified: true, role: 'admin' });
  const response = await request(app).get(endpoint).set('Authorization', `Bearer ${token}`).expect(200);
  expect(response.headers['cache-control']).toBe('no-store');
  expect(response.body.runtime).toMatchObject({ nodeVersion: process.version, inFlight: 0 });
  expect(response.body.runtime).toHaveProperty('eventLoopWindowSeconds');
});

test('enabling runtime telemetry does not keep a Node process alive', () => {
  expect(() => execFileSync(process.execPath, ['-e', "require('./src/services/runtimeMetrics')"], { cwd: require('node:path').join(__dirname, '..'), timeout: 3000 })).not.toThrow();
});
