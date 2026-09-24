/* eslint-disable @typescript-eslint/no-require-imports -- Node test runner uses a TypeScript VM harness. */
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('typescript');
const React = require('react');
const { create, act } = require('react-test-renderer');

globalThis.IS_REACT_ACT_ENVIRONMENT = true;
const START = Date.parse('2026-09-24T13:00:00.000Z');
const filename = path.join(__dirname, '../src/components/admin/TechnicalTvDashboard.tsx');
const compiled = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, jsx: ts.JsxEmit.ReactJSX, esModuleInterop: true },
}).outputText;

function snapshot(overrides = {}) {
  return {
    collectedAt: new Date(START).toISOString(), collectionMs: 1200, source: 'fixture', partialErrors: [],
    host: {
      cpuCores: 4, cpuPercent: 37.5, loadAverage: [1, 0.8, 0.5], uptimeSeconds: 3600,
      memory: { totalBytes: 8192 * 1024 ** 2, usedBytes: 2048 * 1024 ** 2, percent: 25 },
      swap: { totalBytes: 0, usedBytes: 0, percent: 0 },
      disk: { totalBytes: 100 * 1024 ** 3, usedBytes: 20 * 1024 ** 3, percent: 20 },
      kernel: 'test-kernel', networkRxBytes: 1024, networkTxBytes: 2048,
    },
    containers: [], database: null, redis: null, logs: null, backups: null,
    release: null, integrations: null, queues: null,
    http: { api: { status: 'ok', httpStatus: 200, latencyMs: 84, database: 'connected', redis: 'connected', uptimeSeconds: 600, paymentMode: 'live' }, web: { httpStatus: 200, latencyMs: 110 }, tls: null },
    runtime: {
      startedAt: new Date(START - 600000).toISOString(), sampledAt: new Date(START).toISOString(),
      uptimeSeconds: 600, nodeVersion: 'v22.0.0', windowSeconds: 300, requests: 70, requestsPerMinute: 14,
      statusCounts: { success: 68, clientError: 2, serverError: 0 }, errorRatePercent: 0,
      p50Ms: 25, p95Ms: 61, maxMs: 92, inFlight: 0, heapUsedBytes: 40 * 1024 ** 2,
      heapTotalBytes: 80 * 1024 ** 2, rssBytes: 120 * 1024 ** 2,
      eventLoopP95Ms: 2, eventLoopWindowSeconds: 20, droppedSamples: 0, slowRoutes: [],
    },
    runtimeError: null,
    ...overrides,
  };
}
function response(body = snapshot(), status = 200) { return { status, ok: status >= 200 && status < 300, json: async () => body }; }

function harness(fetcher = async () => response()) {
  const timers = new Map();
  const listeners = new Map();
  const redirects = [];
  const calls = [];
  let now = START;
  let nextTimer = 0;
  const setTimeout = (callback, delay) => { const id = ++nextTimer; timers.set(id, { callback, delay, interval: false }); return id; };
  const clearTimeout = id => timers.delete(id);
  const setInterval = (callback, delay) => { const id = setTimeout(callback, delay); timers.get(id).interval = true; return id; };
  const addEventListener = (name, callback) => { if (!listeners.has(name)) listeners.set(name, new Set()); listeners.get(name).add(callback); };
  const removeEventListener = (name, callback) => listeners.get(name)?.delete(callback);
  const router = { replace: value => redirects.push(value) };
  class ClockDate extends Date {
    constructor(...args) { super(...(args.length ? args : [now])); }
    static now() { return now; }
  }
  const loaded = { exports: {} };
  vm.runInNewContext(compiled, {
    module: loaded, exports: loaded.exports,
    require: name => {
      if (name === 'next/link') return ({ children, ...props }) => React.createElement('a', props, children);
      if (name === 'next/navigation') return { useRouter: () => router };
      if (name === './TvDashboard') return { TvDashboard: ({ embedded, refreshKey }) => React.createElement('section', { 'data-business-dashboard': true, 'data-embedded': embedded, 'data-refresh-key': refreshKey }, 'Business dashboard') };
      if (name.endsWith('.module.css')) return { __esModule: true, default: new Proxy({}, { get: (_, key) => key }) };
      return require(name);
    },
    fetch: (...args) => { calls.push(args); return fetcher(...args); },
    window: { addEventListener, removeEventListener },
    document: { fullscreenElement: null, documentElement: {}, addEventListener, removeEventListener },
    navigator: { onLine: true }, AbortController, Date: ClockDate, console,
    setTimeout, clearTimeout, setInterval, clearInterval: clearTimeout,
  }, { filename });
  return {
    Component: loaded.exports.TechnicalTvDashboard, timers, listeners, redirects, calls,
    setFetcher(next) { fetcher = next; },
    advance(milliseconds) { now += milliseconds; },
    async fireTimers(delay) {
      await act(async () => {
        for (const [id, timer] of [...timers]) {
          if (timer.delay !== delay || !timers.has(id)) continue;
          if (!timer.interval) timers.delete(id);
          timer.callback();
        }
      });
    },
  };
}
function text(node) {
  if (typeof node === 'string' || typeof node === 'number') return String(node);
  return node?.children?.map(text).join('') ?? '';
}
function button(renderer, label) { return renderer.root.findByProps({ 'aria-label': label }); }
function cpuMetric(renderer) { return renderer.root.findAllByType('article').find(node => text(node).includes('VPS CPU')); }
async function click(renderer, label) { await act(async () => button(renderer, label).props.onClick()); }
async function mount(t, setup) {
  let renderer;
  await act(async () => { renderer = create(React.createElement(setup.Component)); });
  t.after(async () => { await act(async () => renderer.unmount()); });
  await setup.fireTimers(0);
  return renderer;
}

test('technical TV rotates every 25 seconds, pauses, and still permits manual navigation', async t => {
  const setup = harness();
  const renderer = await mount(t, setup);
  const title = () => text(renderer.root.findByType('h1'));
  assert.equal(title(), 'Teknik özet');
  await setup.fireTimers(25_000);
  assert.equal(title(), 'Veri & kuyruklar');
  await click(renderer, 'Otomatik geçişi duraklat');
  await setup.fireTimers(25_000);
  assert.equal(title(), 'Veri & kuyruklar', 'pause must cancel the pending page transition');
  await click(renderer, 'Sonraki ekran');
  assert.equal(title(), 'Yazılım & tanılama');
  await click(renderer, 'Önceki ekran');
  assert.equal(title(), 'Veri & kuyruklar');
  await click(renderer, 'Otomatik geçişi başlat');
  await setup.fireTimers(25_000);
  assert.equal(title(), 'Yazılım & tanılama');
  await setup.fireTimers(25_000);
  assert.equal(title(), 'Satış & iş özeti', 'business metrics must be part of the automatic rotation');
  await setup.fireTimers(25_000);
  assert.equal(title(), 'Teknik özet', 'rotation must wrap around to the overview');
});

test('sales mounts only on its own page and manual refresh reaches both dashboard data sources', async t => {
  const setup = harness();
  const renderer = await mount(t, setup);
  const sales = () => renderer.root.findAllByProps({ 'data-business-dashboard': true });
  assert.equal(sales().length, 0, 'business polling should not start before the business page is shown');
  await click(renderer, 'Önceki ekran');
  assert.equal(text(renderer.root.findByType('h1')), 'Satış & iş özeti', 'previous from overview wraps to the fourth page');
  assert.equal(sales().length, 1);
  assert.equal(sales()[0].props['data-embedded'], true);
  assert.equal(sales()[0].props['data-refresh-key'], 0);
  const initialFetches = setup.calls.length;
  await click(renderer, 'Verileri yenile');
  assert.equal(setup.calls.length, initialFetches + 1, 'the technical request must also refresh');
  assert.equal(sales()[0].props['data-refresh-key'], 1, 'the embedded business view must receive the refresh trigger');
  await click(renderer, 'Sonraki ekran');
  assert.equal(text(renderer.root.findByType('h1')), 'Teknik özet');
  assert.equal(sales().length, 0, 'leaving the business page must unmount its polling effects');
});

test('technical TV polls after 20 seconds without overlap and aborts pending work on unmount', async t => {
  let finish;
  let requestSignal;
  const setup = harness((_url, options) => new Promise((resolve, reject) => {
    requestSignal = options.signal;
    options.signal.addEventListener('abort', () => reject(new Error('Aborted')), { once: true });
    finish = () => resolve(response());
  }));
  const renderer = await mount(t, setup);
  assert.equal(setup.calls.length, 1);
  assert.equal(setup.calls[0][0], '/api/admin/operations');
  assert.equal(setup.calls[0][1].credentials, 'same-origin');
  assert.equal(setup.calls[0][1].cache, 'no-store');
  assert.equal(button(renderer, 'Verileri yenile').props.disabled, true);
  await setup.fireTimers(20_000);
  await click(renderer, 'Verileri yenile');
  assert.equal(setup.calls.length, 1, 'a manual refresh must not overlap the running poll');
  assert.equal([...setup.timers.values()].filter(timer => timer.delay === 20_000).length, 0);
  await act(async () => finish());
  assert.equal([...setup.timers.values()].filter(timer => timer.delay === 20_000).length, 1);
  await setup.fireTimers(20_000);
  assert.equal(setup.calls.length, 2);
  await act(async () => renderer.unmount());
  assert.equal(requestSignal.aborted, true);
  assert.equal(setup.timers.size, 0, 'abort completion must not schedule more polling');
  assert.equal([...setup.listeners.values()].reduce((sum, group) => sum + group.size, 0), 0);
  await setup.fireTimers(20_000);
  assert.equal(setup.calls.length, 2);
});

test('a slow telemetry request survives page rotation and times out after 60 seconds, then recovers', async t => {
  let requestSignal;
  const setup = harness((_url, options) => new Promise((_resolve, reject) => {
    requestSignal = options.signal;
    options.signal.addEventListener('abort', () => reject(new Error('Timed out')), { once: true });
  }));
  const renderer = await mount(t, setup);
  await setup.fireTimers(25_000);
  assert.equal(requestSignal.aborted, false, '25 second screen rotation must not abort the telemetry request');
  assert.equal(text(renderer.root.findByType('h1')), 'Veri & kuyruklar');
  await setup.fireTimers(60_000);
  assert.equal(requestSignal.aborted, true);
  assert.equal(button(renderer, 'Verileri yenile').props.disabled, false);
  assert.match(text(renderer.root), /VERİ ALINAMADI/);
  setup.setFetcher(async () => response());
  await setup.fireTimers(20_000);
  await click(renderer, 'Önceki ekran');
  assert.equal(setup.calls.length, 2);
  assert.equal(text(cpuMetric(renderer).findByType('strong')), '37,5%');
  assert.doesNotMatch(text(cpuMetric(renderer)), /eski veri/);
});

test('missing sources retain last measurements with stale labels while healthy sources update', async t => {
  const setup = harness();
  const renderer = await mount(t, setup);
  assert.match(text(cpuMetric(renderer)), /37,5%/);
  const initial = snapshot();
  setup.setFetcher(async () => response(snapshot({
    collectedAt: new Date(START + 20000).toISOString(), host: null, partialErrors: ['Sunucu ölçümü alınamadı'],
    runtime: { ...initial.runtime, p95Ms: 140 },
  })));
  await setup.fireTimers(20_000);
  assert.match(text(cpuMetric(renderer)), /37,5%/);
  assert.match(text(cpuMetric(renderer)), /eski veri/);
  const p95 = renderer.root.findAllByType('article').find(node => text(node).includes('API yanıt'));
  assert.match(text(p95), /140 ms/);
  assert.doesNotMatch(text(p95), /eski veri/);
  assert.match(text(renderer.root.findByProps({ role: 'status' })), /Sunucu/);
  setup.setFetcher(async () => response(snapshot({ host: { ...initial.host, cpuPercent: 0 } })));
  await setup.fireTimers(20_000);
  assert.equal(text(cpuMetric(renderer).findByType('strong')), '0%', 'a measured zero is valid data');
  assert.doesNotMatch(text(cpuMetric(renderer)), /eski veri/);
});

test('unavailable initial metrics show unknown values, not healthy zeros', async t => {
  const setup = harness(async () => response(snapshot({ host: null, runtime: null, runtimeError: 'Runtime unavailable', partialErrors: ['Sunucu ölçümü alınamadı'] })));
  const renderer = await mount(t, setup);
  assert.equal(text(cpuMetric(renderer).findByType('strong')), '—');
  const p95 = renderer.root.findAllByType('article').find(node => text(node).includes('API yanıt'));
  assert.equal(text(p95.findByType('strong')), '—');
  assert.match(text(renderer.root), /TELEMETRİ EKSİK/);
  assert.doesNotMatch(text(renderer.root), /SERVİSLER HAZIR/);
});

test('cached host failure marks retained host data stale immediately, before the 90 second threshold', async t => {
  const setup = harness();
  const renderer = await mount(t, setup);
  setup.setFetcher(async () => response(snapshot({ partialErrors: ['Sunucu bağlantısı: eski ölçümler gösteriliyor.'] })));
  await setup.fireTimers(20_000);
  assert.match(text(renderer.root), /VERİ ESKİ/);
  assert.match(text(cpuMetric(renderer)), /37,5%.*eski veri|eski veri.*37,5%/);
  assert.match(text(renderer.root.findByProps({ role: 'status' })), /güncel değil/);
});

test('fresh API runtime remains current when independent host collection returns an old snapshot', async t => {
  const setup = harness();
  const renderer = await mount(t, setup);
  const initial = snapshot();
  setup.advance(120_000);
  await setup.fireTimers(1000);
  setup.setFetcher(async () => response(snapshot({
    partialErrors: ['Sunucu bağlantısı: eski ölçümler gösteriliyor.'],
    runtime: { ...initial.runtime, sampledAt: new Date(START + 120_000).toISOString(), p95Ms: 140 },
  })));
  await setup.fireTimers(20_000);
  assert.match(text(renderer.root), /VERİ ESKİ/);
  assert.match(text(cpuMetric(renderer)), /eski veri/);
  const p95 = () => renderer.root.findAllByType('article').find(node => text(node).includes('API yanıt'));
  assert.equal(text(p95().findByType('strong')), '140 ms');
  assert.doesNotMatch(text(p95()), /eski veri/, 'runtime freshness must use sampledAt, not the host collectedAt or SSH failure');
  setup.advance(90_001);
  await setup.fireTimers(1000);
  assert.match(text(p95()), /eski veri/, 'runtime still expires after its own 90 second freshness window');
});

test('network failure preserves the last readings; an old timestamp also becomes stale after 90 seconds', async t => {
  const setup = harness();
  const renderer = await mount(t, setup);
  setup.advance(90_001);
  await setup.fireTimers(1000);
  assert.match(text(renderer.root), /VERİ ESKİ/);
  assert.match(text(cpuMetric(renderer)), /37,5%/);
  setup.setFetcher(async () => { throw new Error('Network unavailable'); });
  await setup.fireTimers(20_000);
  assert.match(text(cpuMetric(renderer)), /eski veri/);
  assert.equal(button(renderer, 'Verileri yenile').props.disabled, false, 'a failed request must release the fetch lock');
});

test('403 removes existing telemetry and prevents all subsequent fetches', async t => {
  const setup = harness();
  const renderer = await mount(t, setup);
  assert.match(text(cpuMetric(renderer)), /37,5%/);
  setup.setFetcher(async () => response(null, 403));
  await setup.fireTimers(20_000);
  assert.equal(renderer.root.findAllByType('article').length, 0);
  assert.doesNotMatch(text(renderer.root), /37,5%/);
  assert.match(text(renderer.root), /yönetici yetkisi gerekiyor/);
  assert.equal(button(renderer, 'Verileri yenile').props.disabled, true);
  await setup.fireTimers(20_000);
  await click(renderer, 'Verileri yenile');
  assert.equal(setup.calls.length, 2);
  assert.deepEqual(setup.redirects, [], 'forbidden is a visible authorization failure, not a login loop');
});

test('401 clears the screen and redirects to login with the TV return path', async t => {
  const setup = harness(async () => response(null, 401));
  const renderer = await mount(t, setup);
  assert.deepEqual(setup.redirects, ['/giris?next=%2Fadmin%2Ftv']);
  assert.equal(renderer.root.findAllByType('article').length, 0);
  await setup.fireTimers(20_000);
  assert.equal(setup.calls.length, 1);
});

test('invalid snapshot timestamps are rejected without replacing prior measurements', async t => {
  const setup = harness();
  const renderer = await mount(t, setup);
  const initial = snapshot();
  setup.setFetcher(async () => response(snapshot({ collectedAt: 'not-a-date', host: { ...initial.host, cpuPercent: 99 } })));
  await setup.fireTimers(20_000);
  assert.equal(text(cpuMetric(renderer).findByType('strong')), '37,5%');
  assert.match(text(cpuMetric(renderer)), /eski veri/);
  assert.doesNotMatch(text(renderer.root), /Invalid Date/);
});
