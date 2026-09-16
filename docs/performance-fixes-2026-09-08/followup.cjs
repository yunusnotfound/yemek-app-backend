// Follow-up against the isolated database created by benchmark.cjs. No .env.
const fs = require('node:fs'), path = require('node:path'), http = require('node:http');
const { fork } = require('node:child_process');
const { performance } = require('node:perf_hooks');
const { randomUUID } = require('node:crypto');
const assert = require('node:assert/strict');
assert(Number(process.env.PERF_DB_PORT) > 1024 && Number(process.env.PERF_DB_PORT) !== 5432);
assert(Number(process.env.PERF_REDIS_PORT) > 1024 && Number(process.env.PERF_REDIS_PORT) !== 6379);
for (const k of ['DATABASE_URL', 'RESEND_API_KEY', 'IYZICO_API_KEY', 'IYZICO_SECRET_KEY', 'SENTRY_DSN', 'GOOGLE_MAPS_API_KEY']) delete process.env[k];
Object.assign(process.env, { NODE_ENV: 'production', DB_HOST: '127.0.0.1', DB_PORT: process.env.PERF_DB_PORT,
  DB_NAME: 'bitir_performance_benchmark', DB_USER: 'postgres', DB_PASSWORD: 'performance-test', DB_SSL: 'false',
  REDIS_URL: `redis://127.0.0.1:${process.env.PERF_REDIS_PORT}/1`, JWT_SECRET: 'isolated-performance-access-secret-00000000',
  JWT_REFRESH_SECRET: 'isolated-performance-refresh-secret-00000000', LOG_LEVEL: 'error' });
const { sequelize, User, SurprisePackage, Order } = require('../../src/models');
const cache = require('../../src/services/cacheService');
const jwt = require('jsonwebtoken');
const report = { timestamp: new Date().toISOString(), sustained: [], probes: {} };
const save = () => fs.writeFileSync(path.join(__dirname, 'followup-results.json'), JSON.stringify(report, null, 2));
let child, port, n = 0, rpcId = 0, tokens, users;
const pending = new Map();
const agent = new http.Agent({ keepAlive: true, maxSockets: 100 });
const rpc = op => new Promise((resolve, reject) => { const id = ++rpcId; pending.set(id, { resolve, reject }); child.send({ id, op }); });
function request(route, { token, body, ip } = {}) {
  const start = performance.now();
  return new Promise(resolve => {
    const headers = {};
    if (token) headers.authorization = `Bearer ${token}`;
    if (ip) headers['x-forwarded-for'] = ip;
    const data = body ? JSON.stringify(body) : null;
    if (data) { headers['content-type'] = 'application/json'; headers['content-length'] = Buffer.byteLength(data); }
    const req = http.request({ host: '127.0.0.1', port, path: route, method: data ? 'POST' : 'GET', headers, agent }, res => {
      const chunks = [];
      res.on('data', c => chunks.push(c)); res.on('end', () => { const raw = Buffer.concat(chunks); let json;
        try { json = JSON.parse(raw.toString()); } catch {}
        resolve({ status: res.statusCode, ms: performance.now() - start, bytes: raw.length, json }); });
    });
    req.setTimeout(65000, () => req.destroy(new Error('timeout')));
    req.on('error', e => resolve({ status: 0, ms: performance.now() - start, bytes: 0, error: e.message }));
    if (data) req.write(data); req.end();
  });
}
function summary(samples) {
  const lat = samples.map(r => r.ms).sort((a, b) => a - b), statuses = {};
  for (const r of samples) statuses[r.status] = (statuses[r.status] || 0) + 1;
  return { requests: samples.length, statusCounts: statuses, medianMs: lat[Math.ceil(lat.length * .5) - 1],
    p95Ms: lat[Math.ceil(lat.length * .95) - 1], p99Ms: lat[Math.ceil(lat.length * .99) - 1], maxMs: lat.at(-1),
    avgResponseKiB: samples.reduce((a, r) => a + r.bytes, 0) / samples.length / 1024 };
}
async function sustained(name, route, concurrency, makeOptions) {
  await rpc('start'); const start = performance.now(), stopAt = start + 6000, samples = [];
  await Promise.all(Array.from({ length: concurrency }, async () => {
    while (performance.now() < stopAt) {
      const i = n++;
      const r = await request(typeof route === 'function' ? route(i) : route,
        makeOptions ? makeOptions(i) : { token: tokens[i % tokens.length] });
      samples.push({ status: r.status, ms: r.ms, bytes: r.bytes });
    }
  }));
  const seconds = (performance.now() - start) / 1000, metrics = await rpc('stop');
  const row = { name, concurrency, seconds, ...summary(samples), requestsPerSecond: samples.length / seconds,
    ...metrics, queriesPerRequest: metrics.queries / samples.length };
  report.sustained.push(row); save(); console.log(JSON.stringify(row));
}
async function main() {
  users = await User.findAll({ attributes: ['id', 'email', 'role'], order: [['email', 'ASC']], raw: true });
  tokens = users.map(u => jwt.sign({ id: u.id, role: u.role, version: 0, type: 'access' }, process.env.JWT_SECRET, { expiresIn: '1h' }));
  child = fork(path.join(__dirname, 'benchmark-server.cjs'), [], { env: process.env, stdio: ['ignore', 'inherit', 'inherit', 'ipc'] });
  child.on('message', m => { const item = pending.get(m.id); if (item) {
    pending.delete(m.id); m.error ? item.reject(new Error(m.error)) : item.resolve(m.result);
  } });
  await new Promise((resolve, reject) => { child.on('message', m => { if (m.ready) { port = m.port; resolve(); } }); child.once('exit', code => reject(new Error(`Server exited ${code}`))); });
  const base = '/api/packages?lat=41&lng=29&radius=50&limit=10';
  await request(base, { token: tokens[0] });
  await sustained('packages-cache-hit', base, 50);
  await sustained('packages-cache-miss', i => base.replace('radius=50', `radius=${50 + i / 10000000}`), 50);
  await sustained('coupons-100', '/api/coupons/mine', 50);
  await sustained('map-cache-hit', '/api/maps/nearby?lat=41&lng=29&radius=50', 50);
  const [orderUsers] = await sequelize.query('SELECT DISTINCT "userId" FROM "Orders" LIMIT 100');
  const orderTokens = orderUsers.map(r => tokens[users.findIndex(u => u.id === r.userId)]);
  const checkHistory = await request('/api/orders?limit=20', { token: orderTokens[0] });
  report.probes.orderHistoryRows = checkHistory.json?.data?.length;
  await sustained('orders-history-nonempty', '/api/orders?limit=20', 10, i => ({ token: orderTokens[i % orderTokens.length] }));
  // Do CPU-heavy password logins delay otherwise cheap package requests?
  await rpc('start'); const browse = [], logins = [], stopAt = performance.now() + 6000;
  await Promise.all(Array.from({ length: 10 }, async (_, worker) => {
    while (performance.now() < stopAt) {
      const i = n++, isLogin = worker < 5;
      const r = await request(isLogin ? '/api/auth/login' : base, isLogin
        ? { body: { email: users[i % users.length].email, password: 'Benchmark-password-123' }, ip: `198.19.${Math.floor(i / 250) % 250}.${i % 250 + 1}` }
        : { token: tokens[i % tokens.length] });
      (isLogin ? logins : browse).push(r);
    }
  }));
  report.probes.mixedPasswordTraffic = { browsing: summary(browse), logins: summary(logins), metrics: await rpc('stop') };
  save(); console.log('mixedPasswordTraffic', JSON.stringify(report.probes.mixedPasswordTraffic));
  // Deliberately test around the configured pool.max=20 using real transactions.
  const template = (await SurprisePackage.findOne()).toJSON();
  report.probes.stockContention = [];
  for (const concurrency of [10, 20, 50]) {
    const pkg = await SurprisePackage.create({ ...template, id: randomUUID(), title: `Local contention ${concurrency}`,
      discountedPrice: 0, quantity: 10, remainingQuantity: 10 });
    await rpc('start');
    const started = performance.now();
    const requests = Array.from({ length: concurrency }, (_, i) => request('/api/orders', {
      token: tokens[1000 + i], body: { packageId: pkg.id, quantity: 1 } }));
    const snapshot = new Promise(resolve => setTimeout(async () => {
      const [rows] = await sequelize.query(`SELECT state, wait_event_type, wait_event, COUNT(*)::int count
        FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid()
        GROUP BY state, wait_event_type, wait_event`); resolve(rows);
    }, 1200));
    const samples = await Promise.all(requests), seconds = (performance.now() - started) / 1000;
    const metrics = await rpc('stop'), dbWaits = await snapshot;
    await pkg.reload();
    const row = { concurrency, seconds, ...summary(samples), metrics, remainingQuantity: pkg.remainingQuantity,
      createdOrders: await Order.count({ where: { packageId: pkg.id } }), waitsAfter1200ms: dbWaits,
      messages: [...new Set(samples.map(r => r.json?.message ?? r.error))] };
    report.probes.stockContention.push(row); save(); console.log('stockContention', JSON.stringify(row));
  }
  await rpc('close'); child = null; agent.destroy(); await cache.quit(); await sequelize.close();
}
main().catch(async error => {
  console.error(error); report.error = error.stack; save(); if (child) child.kill(); agent.destroy();
  await cache.quit(); await sequelize.close(); process.exitCode = 1;
});
