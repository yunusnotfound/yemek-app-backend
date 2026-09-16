// Measure the local standalone production server; not a browser Web Vitals test.
const fs = require('node:fs'), path = require('node:path'), http = require('node:http'), zlib = require('node:zlib');
const { performance } = require('node:perf_hooks');
const agent = new http.Agent({ keepAlive: true, maxSockets: 20 });
const port = Number(process.env.PERF_WEB_PORT);
if (!port || port === 3000) throw new Error('Use a dedicated PERF_WEB_PORT');
function get(route) {
  const start = performance.now();
  return new Promise((resolve, reject) => {
    const req = http.get({ host: '127.0.0.1', port, path: route, agent, headers: { 'accept-encoding': 'gzip' } }, res => {
      const ttfb = performance.now() - start, chunks = [];
      res.on('data', b => chunks.push(b)); res.on('end', () => {
        const raw = Buffer.concat(chunks), data = res.headers['content-encoding'] === 'gzip' ? zlib.gunzipSync(raw) : raw;
        resolve({ status: res.statusCode, ms: performance.now() - start, ttfb, transferBytes: raw.length,
          bodyBytes: data.length, body: data.toString() });
      });
    }); req.setTimeout(10000, () => req.destroy(new Error('timeout'))); req.on('error', reject);
  });
}
(async () => {
  const first = await get('/');
  const scripts = [...new Set([...first.body.matchAll(/<script[^>]*src="([^"]+)"/g)].map(m => m[1]))];
  const assets = [];
  for (const src of scripts) { const r = await get(src); assets.push({ src, status: r.status, transferBytes: r.transferBytes, bodyBytes: r.bodyBytes }); }
  const report = { mode: 'Next standalone production server, loopback HTTP gzip, no browser rendering',
    firstHomeResponse: { status: first.status, ttfbMs: first.ttfb, completeMs: first.ms, transferBytes: first.transferBytes }, homeScripts: assets, scenarios: [] };
  for (const route of ['/', '/giris']) {
    for (const concurrency of [1, 10]) {
      const start = performance.now(), until = start + 2000, samples = [];
      await Promise.all(Array.from({ length: concurrency }, async () => {
        while (performance.now() < until) { const r = await get(route); samples.push({ status: r.status, ms: r.ms, ttfb: r.ttfb }); }
      }));
      const seconds = (performance.now() - start) / 1000, times = samples.map(r => r.ms).sort((a, b) => a - b), statuses = {};
      for (const r of samples) statuses[r.status] = (statuses[r.status] || 0) + 1;
      report.scenarios.push({ route, concurrency, requests: samples.length, seconds, requestsPerSecond: samples.length / seconds,
        p50Ms: times[Math.ceil(times.length * .5) - 1], p95Ms: times[Math.ceil(times.length * .95) - 1], statusCounts: statuses });
    }
  }
  fs.writeFileSync(path.join(__dirname, 'web-http-results.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report)); agent.destroy();
})().catch(error => { console.error(error); agent.destroy(); process.exit(1); });
