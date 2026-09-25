// Exercise production static-file and rate-limit middleware without a database.
jest.mock('../src/routes', () => {
  const router = require('express').Router();
  router.use((req, res) => res.json({ ok: true }));
  return router;
});
jest.mock('../src/services/logger', () => ({ error: jest.fn() }));

const fs = require('fs');
const path = require('path');
const { randomUUID } = require('crypto');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const savedEnvironment = process.env.NODE_ENV;
process.env.NODE_ENV = 'production';
const app = require('../src/app');
process.env.NODE_ENV = savedEnvironment;

const uploadsDirectory = path.join(__dirname, '..', 'uploads');
const immutableName = `${randomUUID()}.png`;
const legacyName = `cache-test-${randomUUID()}.png`;
const catalogDirectory = `demo-catalog-v${Date.now()}`;
const image = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a9i8AAAAASUVORK5CYII=', 'base64');
const imagePath = `/uploads/${immutableName}`;
let server;

beforeAll(async () => {
  await fs.promises.mkdir(path.join(uploadsDirectory, catalogDirectory), { recursive: true });
  await Promise.all([
    fs.promises.writeFile(path.join(uploadsDirectory, immutableName), image),
    fs.promises.writeFile(path.join(uploadsDirectory, legacyName), image),
    fs.promises.writeFile(path.join(uploadsDirectory, catalogDirectory, 'food.png'), image),
  ]);
  await new Promise((resolve) => { server = app.listen(0, '127.0.0.1', resolve); });
});

afterAll(async () => {
  await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  await Promise.all([
    fs.promises.unlink(path.join(uploadsDirectory, immutableName)),
    fs.promises.unlink(path.join(uploadsDirectory, legacyName)),
    fs.promises.rm(path.join(uploadsDirectory, catalogDirectory), { recursive: true }),
  ]);
});

test('UUID images are immutable and public across origins without credentialed CORS', async () => {
  const response = await request(server).get(imagePath).set('Origin', 'https://images.example');
  expect(response.status).toBe(200);
  expect(response.body).toEqual(image);
  expect(response.headers['cache-control']).toBe('public, max-age=31536000, immutable');
  expect(response.headers['access-control-allow-origin']).toBe('*');
  expect(response.headers['access-control-allow-credentials']).toBeUndefined();
  expect(response.headers.vary).toBeUndefined();
  expect(response.headers['cross-origin-resource-policy']).toBe('cross-origin');
  expect(response.headers['x-content-type-options']).toBe('nosniff');
  expect(response.headers['content-security-policy']).toBe("default-src 'none'; sandbox");
  expect(response.headers['ratelimit-limit']).toBeUndefined();
});

test('existing catalog and legacy image URLs have bounded cache lifetimes', async () => {
  const catalog = await request(server).get(`/uploads/${catalogDirectory}/food.png`);
  expect(catalog.status).toBe(200);
  expect(catalog.headers['cache-control']).toBe('public, max-age=604800');
  const legacy = await request(server).get(`/uploads/${legacyName}`);
  expect(legacy.status).toBe(200);
  expect(legacy.headers['cache-control']).toBe('public, max-age=86400');
});

test('HEAD and conditional requests retain validators and image caching', async () => {
  const head = await request(server).head(imagePath);
  expect(head.status).toBe(200);
  expect(head.headers['content-length']).toBe(String(image.length));
  const unchanged = await request(server).get(imagePath).set('If-None-Match', head.headers.etag);
  expect(unchanged.status).toBe(304);
  expect(unchanged.headers['cache-control']).toBe('public, max-age=31536000, immutable');
});

test('missing images, directories, invalid ranges and unsupported methods are not cached', async () => {
  const responses = await Promise.all([
    request(server).get(`/uploads/${randomUUID()}.png`),
    request(server).get(`/uploads/${catalogDirectory}/`),
    request(server).get(imagePath).set('Range', 'bytes=99999-'),
    request(server).post(imagePath).send({}),
  ]);
  expect(responses.map((response) => response.status)).toEqual([404, 404, 416, 405]);
  expect(responses[0].body).toEqual({ success: false, message: 'Görsel bulunamadı' });
  expect(JSON.stringify(responses[0].body)).not.toContain('ENOENT');
  expect(JSON.stringify(responses[0].body)).not.toContain(uploadsDirectory);
  for (const response of responses) {
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.headers['ratelimit-limit']).toBeUndefined();
  }
});

test('more than 100 image requests do not exhaust the API budget', async () => {
  const token = jwt.sign({ id: randomUUID(), role: 'customer' }, process.env.JWT_SECRET, {
    algorithm: 'HS256', expiresIn: '15m',
  });
  for (let index = 0; index < 101; index++) {
    const response = await request(server).get(imagePath).set('Authorization', `Bearer ${token}`);
    expect(response.status).toBe(200);
  }
  const api = await request(server).get('/api/orders').set('Authorization', `Bearer ${token}`);
  expect(api.status).toBe(200);
  expect(api.headers['ratelimit-limit']).toBe('100');
  expect(api.headers['ratelimit-remaining']).toBe('99');
});

test('public image CORS does not widen credentialed API access', async () => {
  const response = await request(server).get('/api/orders').set('Origin', 'https://images.example');
  expect(response.status).toBe(403);
  expect(response.headers['access-control-allow-origin']).toBeUndefined();
});
