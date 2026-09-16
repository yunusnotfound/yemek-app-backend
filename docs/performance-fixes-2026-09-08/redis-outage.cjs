// Exercise real cache-fallback behavior against a closed local port. No remote services.
const fs = require('node:fs'), path = require('node:path'), net = require('node:net');
const { performance } = require('node:perf_hooks');
const assert = require('node:assert/strict');
assert(Number(process.env.PERF_DB_PORT) > 1024 && Number(process.env.PERF_DB_PORT) !== 5432);
for (const k of ['DATABASE_URL', 'RESEND_API_KEY', 'IYZICO_API_KEY', 'IYZICO_SECRET_KEY', 'SENTRY_DSN', 'GOOGLE_MAPS_API_KEY']) delete process.env[k];
Object.assign(process.env, { NODE_ENV: 'production', DB_HOST: '127.0.0.1', DB_PORT: process.env.PERF_DB_PORT,
  DB_NAME: 'bitir_performance_benchmark', DB_USER: 'postgres', DB_PASSWORD: 'performance-test', DB_SSL: 'false',
  JWT_SECRET: 'isolated-performance-access-secret-00000000', JWT_REFRESH_SECRET: 'isolated-performance-refresh-secret-00000000', LOG_LEVEL: 'error' });
(async () => {
  const placeholder = net.createServer();
  await new Promise(resolve => placeholder.listen(0, '127.0.0.1', resolve));
  const closedPort = placeholder.address().port;
  await new Promise(resolve => placeholder.close(resolve));
  process.env.REDIS_URL = `redis://127.0.0.1:${closedPort}`;
  const app = require('../../src/app'), { sequelize } = require('../../src/models'), cache = require('../../src/services/cacheService');
  const request = require('supertest');
  const report = { fault: 'Connection refused on an unused loopback Redis port', results: [] };
  for (let i = 0; i < 3; i++) {
    const start = performance.now();
    const result = await request(app).get('/api/packages?lat=41&lng=29&radius=50&limit=10').timeout(20000);
    report.results.push({ ms: performance.now() - start, status: result.status, returned: result.body?.data?.length });
  }
  fs.writeFileSync(path.join(__dirname, 'redis-outage-results.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report)); await cache.quit(); await sequelize.close();
})().catch(error => { console.error(error); process.exit(1); });
