// Run only against a newly created, isolated local PostgreSQL/Redis pair.
// PERF_DB_PORT and PERF_REDIS_PORT are required; normal application .env is never loaded.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const http = require('node:http');
const { fork } = require('node:child_process');
const { randomUUID } = require('node:crypto');
const { performance } = require('node:perf_hooks');
const assert = require('node:assert/strict');
const dbPort = Number(process.env.PERF_DB_PORT), redisPort = Number(process.env.PERF_REDIS_PORT);
assert(dbPort > 1024 && redisPort > 1024 && dbPort !== 5432 && redisPort !== 6379);
for (const key of ['DATABASE_URL', 'RESEND_API_KEY', 'IYZICO_API_KEY', 'IYZICO_SECRET_KEY', 'SENTRY_DSN', 'GOOGLE_MAPS_API_KEY']) delete process.env[key];
Object.assign(process.env, { NODE_ENV: 'production', DB_HOST: '127.0.0.1', DB_PORT: String(dbPort),
  DB_NAME: 'bitir_performance_benchmark', DB_USER: 'postgres', DB_PASSWORD: 'performance-test', DB_SSL: 'false',
  REDIS_URL: `redis://127.0.0.1:${redisPort}/1`, JWT_SECRET: 'isolated-performance-access-secret-00000000',
  JWT_REFRESH_SECRET: 'isolated-performance-refresh-secret-00000000', LOG_LEVEL: 'error' });
const { Client } = require('pg');
const S = require('sequelize');
const jwt = require('jsonwebtoken');
const out = __dirname;
const report = { timestamp: new Date().toISOString(), environment: { node: process.version, cpu: os.cpus()[0].model,
  cores: os.cpus().length, memoryGiB: os.totalmem() / 1073741824, mode: 'production',
  transport: 'loopback HTTP, keep-alive, closed-loop; rate limiters enabled; synthetic users; no TLS/proxy/cron/Sentry/external APIs' }, scenarios: [], probes: {} };
let sequelize, child, agent, port, users, businesses, packages, coupons, tokenCounter = 0;
const pending = new Map(); let sequence = 0;
const rpc = op => new Promise((resolve, reject) => { const id = ++sequence; pending.set(id, { resolve, reject }); child.send({ id, op }); });
const save = () => fs.writeFileSync(path.join(out, 'benchmark-results.json'), JSON.stringify(report, null, 2));
const quantile = (sorted, p) => sorted[Math.max(0, Math.ceil(sorted.length * p) - 1)];
function request(route, { token, body, ip } = {}) {
  const began = performance.now();
  return new Promise(resolve => {
    const headers = {};
    if (token) headers.authorization = `Bearer ${token}`;
    if (ip) headers['x-forwarded-for'] = ip;
    const data = body ? JSON.stringify(body) : null;
    if (data) { headers['content-type'] = 'application/json'; headers['content-length'] = Buffer.byteLength(data); }
    const req = http.request({ host: '127.0.0.1', port, path: route, method: data ? 'POST' : 'GET', headers, agent }, res => {
      const chunks = [];
      res.on('data', b => chunks.push(b));
      res.on('end', () => { const raw = Buffer.concat(chunks); let json;
        try { json = JSON.parse(raw.toString()); } catch {}
        resolve({ status: res.statusCode, ms: performance.now() - began, bytes: raw.length, json }); });
    });
    req.setTimeout(30000, () => req.destroy(new Error('timeout')));
    req.on('error', error => resolve({ status: 0, ms: performance.now() - began, bytes: 0, error: error.message }));
    if (data) req.write(data); req.end();
  });
}
let tokens;
const nextToken = () => tokens[tokenCounter++ % tokens.length];
async function scenario(name, route, concurrency, count, options = {}) {
  await rpc('start');
  const began = performance.now(), samples = [], statuses = {}; let index = 0, bytes = 0;
  await Promise.all(Array.from({ length: concurrency }, async () => {
    while (index < count) { const i = index++; const r = await request(typeof route === 'function' ? route(i) : route,
      options.login ? { body: { email: users[i % users.length].email, password: 'Benchmark-password-123' }, ip: `198.18.${Math.floor(i / 250)}.${i % 250 + 1}` }
        : { token: options.admin ? tokens.at(-1) : nextToken() });
      samples.push(r.ms); statuses[r.status] = (statuses[r.status] || 0) + 1; bytes += r.bytes;
    }
  }));
  const seconds = (performance.now() - began) / 1000, metrics = await rpc('stop'); samples.sort((a, b) => a - b);
  const result = { name, concurrency, requests: count, seconds, requestsPerSecond: count / seconds,
    medianMs: quantile(samples, .5), p95Ms: quantile(samples, .95), p99Ms: quantile(samples, .99), maxMs: samples.at(-1),
    statusCounts: statuses, avgResponseKiB: bytes / count / 1024, ...metrics, queriesPerRequest: metrics.queries / count };
  report.scenarios.push(result); save(); console.log(JSON.stringify(result)); return result;
}
async function probe(name, route) {
  await rpc('capture'); await rpc('start');
  const result = await request(route, { token: nextToken() });
  const metrics = await rpc('stop'); const statements = await rpc('sql');
  report.probes[name] = { status: result.status, ms: result.ms, bytes: result.bytes, queries: metrics.queries,
    returned: result.json?.data?.length ?? result.json?.coupons?.length ?? result.json?.businesses?.length,
    total: result.json?.pagination?.total };
  fs.writeFileSync(path.join(out, `${name}-queries.sql`), statements.join('\n\n'));
  if (name === 'packages-cold') {
    const plans = [];
    for (const sql of statements.filter(s => s.startsWith('SELECT') && s.includes('SurprisePackages'))) {
      const rows = await sequelize.query(`EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ${sql}`, { type: S.QueryTypes.SELECT });
      plans.push(rows);
    }
    fs.writeFileSync(path.join(out, 'packages-query-plans.json'), JSON.stringify(plans, null, 2));
  }
  save(); return result;
}
async function main() {
  const admin = new Client({ host: '127.0.0.1', port: dbPort, user: 'postgres', database: 'postgres' });
  await admin.connect();
  // CREATE without IF EXISTS deliberately refuses to overwrite any existing database.
  await admin.query('CREATE DATABASE bitir_performance_benchmark'); await admin.end();
  const models = require('../../src/models'); sequelize = models.sequelize;
  for (const file of fs.readdirSync(path.resolve(out, '../../src/migrations')).filter(f => f.endsWith('.js')).sort()) {
    await require(path.resolve(out, '../../src/migrations', file)).up(sequelize.getQueryInterface(), S);
  }
  console.log('All real migrations applied');
  const { User, Business, Category, SurprisePackage, Order, Coupon } = models;
  const password = await require('bcryptjs').hash('Benchmark-password-123', 10);
  users = Array.from({ length: 2000 }, (_, i) => ({ id: randomUUID(), name: `Performance ${i}`, email: `perf-${i}@test.local`,
    password, role: i === 1999 ? 'admin' : i === 0 ? 'business_owner' : 'customer', isEmailVerified: true }));
  await User.bulkCreate(users);
  const categories = await Category.bulkCreate(Array.from({ length: 10 }, (_, i) => ({ name: `Category ${i}`, slug: `perf-${i}` })), { returning: true });
  businesses = Array.from({ length: 2000 }, (_, i) => ({ id: randomUUID(), ownerId: users[0].id,
    categoryId: categories[i % 10].id, name: `Performance Business ${i}`, address: 'Synthetic street', city: 'Istanbul', district: 'Kadikoy',
    latitude: 40.8 + (i % 50) * .008, longitude: 28.8 + Math.floor(i / 50) * .01,
    isActive: true, isApproved: true, approvalStatus: 'approved', subMerchantKey: 'synthetic', subMerchantStatus: 'active' }));
  await Business.bulkCreate(businesses);
  const day = new Date(Date.now() + 3 * 86400000).toISOString().slice(0, 10);
  packages = Array.from({ length: 20000 }, (_, i) => ({ id: randomUUID(), businessId: businesses[i % 2000].id,
    title: `Performance package ${i}`, description: 'Synthetic package for local performance tests.',
    originalPrice: 200, discountedPrice: 90, quantity: 100, remainingQuantity: 100, pickupDate: day,
    pickupStart: '10:00:00', pickupEnd: '23:59:00', isActive: true }));
  for (let i = 0; i < packages.length; i += 2000) await SurprisePackage.bulkCreate(packages.slice(i, i + 2000));
  coupons = Array.from({ length: 100 }, (_, i) => ({ id: randomUUID(), code: `PERF${i}`, title: `Campaign ${i}`,
    discountType: 'percentage', discountValue: 10, minOrderAmount: 0, maxUsage: 1000000, currentUsage: 100,
    perUserLimit: 5, budgetLimit: 1000000, isDiscoverable: i < 10, isActive: true, expiresAt: new Date(Date.now() + 86400000 * 30) }));
  await Coupon.bulkCreate(coupons);
  for (let begin = 0; begin < 50000; begin += 2000) {
    await Order.bulkCreate(Array.from({ length: 2000 }, (_, j) => {
      const i = begin + j;
      return { userId: users[(i % 999) + 1].id, packageId: packages[i % packages.length].id,
        couponId: i % 2 === 0 ? coupons[i % 100].id : null, quantity: 1,
        totalPrice: 90, originalTotal: 200, discountAmount: i % 2 === 0 ? 9 : 0,
        finalPrice: i % 2 === 0 ? 81 : 90, status: 'picked_up', paymentStatus: 'paid',
        pickupCode: String(i % 1000000).padStart(6, '0'), paidAt: new Date(),
        createdAt: new Date(Date.now() - (i % 90) * 86400000) };
    }));
  }
  await sequelize.query('ANALYZE');
  report.dataset = { users: 2000, businesses: 2000, packages: 20000, orders: 50000, coupons: 100,
    schema: 'all repository migrations, including production indexes', distribution: 'synthetic Istanbul grid, all packages active and future, completed historical orders' };
  report.environment.postgres = (await sequelize.query('SELECT version()', { type: S.QueryTypes.SELECT }))[0].version;
  tokens = users.map(user => jwt.sign({ id: user.id, role: user.role, type: 'access', version: 0 }, process.env.JWT_SECRET, { expiresIn: '1h' }));
  agent = new http.Agent({ keepAlive: true, maxSockets: 100 });
  child = fork(path.join(out, 'benchmark-server.cjs'), [], { env: process.env, stdio: ['ignore', 'inherit', 'inherit', 'ipc'] });
  child.on('message', message => { const item = pending.get(message.id); if (item) {
    pending.delete(message.id); message.error ? item.reject(new Error(message.error)) : item.resolve(message.result);
  } });
  await new Promise((resolve, reject) => { child.on('message', m => { if (m.ready) { port = m.port; resolve(); } }); child.once('exit', code => reject(new Error(`Server exited ${code}`))); });
  const base = '/api/packages?lat=41&lng=29&radius=50&limit=10';
  await probe('packages-cold', base);
  await probe('packages-warm', base);
  for (const c of [1, 10, 50]) await scenario('packages-cache-hit', base, c, 1000);
  for (const c of [1, 10, 50]) await scenario('packages-cache-miss', i => `${base.replace('radius=50', `radius=${50 + (i + 1 + c * 1000) / 1000000}`)}`, c, 300);
  await probe('coupons-10', '/api/coupons/mine');
  for (const c of [1, 10, 50]) await scenario('coupons-10', '/api/coupons/mine', c, 100);
  await Coupon.update({ isDiscoverable: true }, { where: {} });
  await probe('coupons-100', '/api/coupons/mine');
  for (const c of [1, 10, 50]) await scenario('coupons-100', '/api/coupons/mine', c, 100);
  const nearby = '/api/maps/nearby?lat=41&lng=29&radius=50';
  await probe('map-cold', nearby); await probe('map-warm', nearby);
  await scenario('map-cache-hit', nearby, 10, 200);
  await scenario('map-cache-hit', nearby, 50, 200);
  await scenario('business-detail', `/api/businesses/${businesses[0].id}`, 10, 200);
  await scenario('orders-history', '/api/orders?limit=20', 10, 200);
  await scenario('coupons-admin-100', '/api/coupons?limit=100', 10, 60, { admin: true });
  for (const c of [1, 10]) await scenario('password-login', '/api/auth/login', c, c === 1 ? 10 : 40, { login: true });
  // Accuracy probe: two points share the same rounded cache cell but different radius memberships.
  const geoBusiness = await Business.create({ ...businesses[0], id: randomUUID(), name: 'Cache boundary probe', latitude: 41.0048, longitude: 29.0048 });
  const cache = require('../../src/services/cacheService');
  await cache.invalidateNamespace('businesses:list');
  const pointA = '/api/businesses?lat=40.9951&lng=28.9951&radius=0.5&limit=100';
  const pointB = '/api/businesses?lat=41.0049&lng=29.0049&radius=0.5&limit=100';
  const a = await request(pointA, { token: nextToken() });
  const staleB = await request(pointB, { token: nextToken() });
  await cache.invalidateNamespace('businesses:list');
  const freshB = await request(pointB, { token: nextToken() });
  const includes = r => r.json?.data?.some(b => b.id === geoBusiness.id);
  report.probes.geoCacheBoundary = { statuses: [a.status, staleB.status, freshB.status], pointAIncludesTarget: includes(a),
    pointBCachedIncludesTarget: includes(staleB), pointBFreshIncludesTarget: includes(freshB),
    explanation: 'Both points round to 41.00,29.00; cache hit reuses exact results from the other coordinate.' };
  // Verify production throttle separately with a fresh user, counted successful responses only.
  const limitToken = jwt.sign({ id: randomUUID() }, process.env.JWT_SECRET, { expiresIn: '1h' });
  const limits = {};
  for (let i = 0; i < 105; i++) { const r = await request('/api/categories', { token: limitToken }); limits[r.status] = (limits[r.status] || 0) + 1; }
  report.probes.productionRateLimit = { path: '/api/categories', responses: limits, windowMinutes: 15 };
  save();
  await cache.quit(); await rpc('close'); child = null; agent.destroy(); await sequelize.close();
}
main().catch(async error => {
  console.error(error); report.error = error.stack; save();
  if (child) child.kill(); if (agent) agent.destroy(); if (sequelize) await sequelize.close(); process.exitCode = 1;
});
