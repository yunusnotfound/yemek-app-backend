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

function harness(api) {
  const cache = new Map();
  const timers = new Map();
  const listeners = new Map();
  let nextTimer = 0;
  const setTimeout = (callback, delay) => {
    const id = ++nextTimer;
    timers.set(id, { callback, delay, interval: false });
    return id;
  };
  const setInterval = (callback, delay) => {
    const id = setTimeout(callback, delay);
    timers.get(id).interval = true;
    return id;
  };
  const clearTimeout = id => timers.delete(id);
  const addEventListener = (name, callback) => {
    if (!listeners.has(name)) listeners.set(name, new Set());
    listeners.get(name).add(callback);
  };
  const removeEventListener = (name, callback) => listeners.get(name)?.delete(callback);
  const window = { setTimeout, clearTimeout, setInterval, clearInterval: clearTimeout, addEventListener, removeEventListener };
  const document = {
    hidden: false,
    visibilityState: 'visible',
    fullscreenElement: null,
    documentElement: {},
    addEventListener,
    removeEventListener,
  };
  const mocks = {
    '@/lib/api/admin': api,
    'next/link': ({ children, ...props }) => React.createElement('a', props, children),
  };
  function load(file) {
    const filename = path.join(__dirname, '../src', file);
    if (cache.has(filename)) return cache.get(filename).exports;
    const output = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
      compilerOptions: {
        module: ts.ModuleKind.CommonJS,
        target: ts.ScriptTarget.ES2022,
        jsx: ts.JsxEmit.ReactJSX,
        esModuleInterop: true,
      },
    }).outputText;
    const loadedModule = { exports: {} };
    cache.set(filename, loadedModule);
    vm.runInNewContext(output, {
      module: loadedModule,
      exports: loadedModule.exports,
      require: name => {
        if (Object.hasOwn(mocks, name)) return mocks[name];
        if (name.endsWith('.module.css')) return { __esModule: true, default: new Proxy({}, { get: (_, key) => key }) };
        if (!name.startsWith('@/')) return require(name);
        const relative = name.slice(2);
        const extension = ['.tsx', '.ts'].find(ext => fs.existsSync(path.join(__dirname, '../src', relative + ext)));
        return load(relative + extension);
      },
      window, document, navigator: { onLine: true }, console, URL,
      setTimeout, clearTimeout, setInterval, clearInterval: clearTimeout,
    }, { filename });
    return loadedModule.exports;
  }
  async function fireTimers(delay) {
    await act(async () => {
      for (const [id, timer] of [...timers]) {
        if (timer.delay !== delay) continue;
        if (!timer.interval) timers.delete(id);
        timer.callback();
      }
    });
  }
  return { load, timers, listeners, fireTimers };
}

function text(node) {
  if (typeof node === 'string' || typeof node === 'number') return String(node);
  return node?.children?.map(text).join('') ?? '';
}

function dashboardStats(overrides = {}) {
  return {
    totalUsers: 12345, totalBusinesses: 42, totalOrders: 250, totalPackages: 80,
    pendingBusinesses: 3, activeBusinesses: 39, todayOrders: 17, todayRevenue: 1230,
    gmv: 90000, commissionTotal: 9000, refundedTotal: 500,
    customers: 12300, businessOwners: 42, admins: 3,
    ...overrides,
  };
}

function settlement(overrides = {}) {
  return { gmv: 90000, commission: 9000, refunded: 500, held: 2100, approved: 87300, heldCount: 7, approvedCount: 230, ...overrides };
}

function orders(title = 'Akşam Paketi') {
  return {
    data: [{
      id: 'order-id-1', status: 'confirmed', paymentStatus: 'paid', quantity: 2,
      finalPrice: 275, totalPrice: 300, createdAt: '2026-09-24T12:00:00Z',
      pickupCode: 'PRIVATE-PICKUP-634981',
      user: { id: 'private-user-id', name: 'Private Customer Name', phone: '05551234567', email: 'private@example.test' },
      package: { id: 'package-1', title, business: { name: 'Örnek İşletme' } },
    }],
    pagination: { total: 1, page: 1, limit: 8, totalPages: 1 },
  };
}

function successfulApi() {
  return {
    getAdminDashboard: async () => ({ stats: dashboardStats() }),
    getSettlementSummary: async () => ({ summary: settlement() }),
    getOrders: async () => orders(),
  };
}

async function mount(t, setup, props = {}) {
  const { TvDashboard } = setup.load('components/admin/TvDashboard.tsx');
  let renderer;
  await act(async () => { renderer = create(React.createElement(TvDashboard, props)); });
  t.after(async () => { await act(async () => renderer.unmount()); });
  await setup.fireTimers(0);
  return renderer;
}

test('TV refresh preserves a failed section while refreshing others and omits customer details', async (t) => {
  const api = successfulApi();
  const setup = harness(api);
  const renderer = await mount(t, setup);
  const overview = () => renderer.root.findByProps({ 'aria-label': 'Platform metrikleri' });
  const orderSection = () => renderer.root.findByProps({ 'aria-labelledby': 'tv-orders-heading' });
  assert.match(text(overview()), /12\.345/);
  assert.match(text(orderSection()), /Akşam Paketi/);
  const rendered = JSON.stringify(renderer.toJSON());
  for (const privateValue of ['Private Customer Name', '05551234567', 'private@example.test', 'PRIVATE-PICKUP-634981', 'private-user-id']) {
    assert.equal(rendered.includes(privateValue), false, `${privateValue} must not appear on a shared TV`);
  }

  api.getAdminDashboard = async () => { throw new Error('Temporary outage'); };
  api.getOrders = async () => orders('Yeni Öğle Paketi');
  await setup.fireTimers(30_000);
  assert.match(text(overview()), /12\.345/, 'last known stats must survive a failed refresh');
  assert.match(text(overview()), /Eski veri/);
  assert.match(text(orderSection()), /Yeni Öğle Paketi/);
  assert.doesNotMatch(text(orderSection()), /Akşam Paketi|Eski veri/);
  assert.match(text(renderer.root.findByProps({ role: 'status' })), /Güncellenemedi: genel bakış/);
});

test('empty successful TV results show zeros and no orders, unavailable results show missing data', async (t) => {
  const zeroStats = Object.fromEntries(Object.keys(dashboardStats()).map(key => [key, 0]));
  const zeroSettlement = Object.fromEntries(Object.keys(settlement()).map(key => [key, 0]));
  const empty = await mount(t, harness({
    getAdminDashboard: async () => ({ stats: zeroStats }),
    getSettlementSummary: async () => ({ summary: zeroSettlement }),
    getOrders: async () => ({ data: [], pagination: { total: 0, page: 1, limit: 6, totalPages: 0 } }),
  }));
  const metrics = empty.root.findByProps({ 'aria-label': 'Platform metrikleri' });
  assert.ok(metrics.findAllByType('strong').every(node => /^₺?0(?:,00)?$/.test(text(node))));
  assert.match(text(empty.root), /Henüz sipariş bulunmuyor\./);
  assert.doesNotMatch(text(metrics), /Veri alınamadı/);

  const unavailable = async () => { throw new Error('Backend unavailable'); };
  const missing = await mount(t, harness({
    getAdminDashboard: unavailable, getSettlementSummary: unavailable, getOrders: unavailable,
  }));
  const missingMetrics = missing.root.findByProps({ 'aria-label': 'Platform metrikleri' });
  assert.ok(missingMetrics.findAllByType('strong').every(node => text(node) === '—'));
  assert.match(text(missingMetrics), /Veri alınamadı/);
  assert.match(text(missing.root), /Siparişler alınamadı/);
  assert.doesNotMatch(text(missing.root), /Henüz sipariş bulunmuyor\./);
});

test('TV polls after completion without overlapping requests and cleans timers on unmount', async (t) => {
  const calls = { stats: 0, settlement: 0, orders: 0 };
  let finishRequest;
  const setup = harness({
    getAdminDashboard: () => {
      calls.stats++;
      return new Promise(resolve => { finishRequest = () => resolve({ stats: dashboardStats() }); });
    },
    getSettlementSummary: async () => { calls.settlement++; return { summary: settlement() }; },
    getOrders: async () => { calls.orders++; return orders(); },
  });
  const renderer = await mount(t, setup);
  const refresh = renderer.root.findByProps({ 'aria-label': 'Verileri yenile' });
  assert.equal(refresh.props.disabled, true);
  assert.deepEqual(calls, { stats: 1, settlement: 1, orders: 1 });
  await setup.fireTimers(30_000);
  await act(async () => { refresh.props.onClick(); });
  assert.deepEqual(calls, { stats: 1, settlement: 1, orders: 1 }, 'slow requests and repeated refresh must not overlap');
  assert.equal([...setup.timers.values()].filter(timer => timer.delay === 30_000).length, 0);

  await act(async () => { finishRequest(); });
  assert.equal([...setup.timers.values()].filter(timer => timer.delay === 30_000).length, 1);
  await setup.fireTimers(30_000);
  assert.deepEqual(calls, { stats: 2, settlement: 2, orders: 2 });
  await act(async () => { renderer.unmount(); });
  await act(async () => { finishRequest(); });
  assert.equal(setup.timers.size, 0, 'an in-flight completion after unmount must not restart polling');
  assert.equal([...setup.listeners.values()].reduce((total, listeners) => total + listeners.size, 0), 0);
  await setup.fireTimers(30_000);
  assert.deepEqual(calls, { stats: 2, settlement: 2, orders: 2 });
});

test('embedded sales screen retains six orders, platform metrics and payment totals without a duplicate header or toolbar', async (t) => {
  const api = successfulApi();
  const statuses = ['paid', 'pending', 'refunded', 'partially_refunded', 'failed', 'unpaid'];
  const orderRequests = [];
  api.getOrders = async options => {
    orderRequests.push(options.limit);
    return {
      data: statuses.map((paymentStatus, index) => ({
        ...orders().data[0], id: `order-${index}`, paymentStatus,
        package: { id: `package-${index}`, title: `Paket ${index + 1}`, business: { name: `İşletme ${index + 1}` } },
      })),
      pagination: { total: 6, page: 1, limit: 6, totalPages: 1 },
    };
  };
  const renderer = await mount(t, harness(api), { embedded: true });
  assert.equal(renderer.root.findByProps({ 'aria-label': 'Satış ve iş metrikleri' }).type, 'section');
  assert.equal(renderer.root.findAllByType('main').length, 0);
  assert.equal(renderer.root.findAllByType('header').length, 0);
  assert.equal(renderer.root.findAllByType('h1').length, 0);
  assert.equal(renderer.root.findAllByProps({ 'aria-label': 'Ekran kontrolleri' }).length, 0);
  assert.equal(renderer.root.findAllByProps({ 'aria-label': 'Verileri yenile' }).length, 0);
  assert.deepEqual(orderRequests, [6]);
  const rows = renderer.root.findByType('tbody').findAllByType('tr');
  assert.equal(rows.length, 6);
  for (let index = 0; index < rows.length; index++) {
    assert.match(text(rows[index]), new RegExp(`İşletme ${index + 1}`));
    assert.match(text(rows[index]), new RegExp(`Paket ${index + 1}`));
  }
  for (const label of ['Ödendi', 'Bekliyor', 'İade', 'Kısmi iade', 'Başarısız', 'Ödenmedi']) {
    assert.ok(rows.some(row => text(row).includes(label)), `${label} payment state must remain visible`);
  }
  const overview = text(renderer.root.findByProps({ 'aria-label': 'Platform metrikleri' }));
  for (const value of ['Bugünkü tahsilat', '1.230', 'Bugünkü ödenmiş sipariş', '17', '90.000', '9.000', '12.345', '42', '80']) {
    assert.ok(overview.includes(value), `${value} business metric must remain visible`);
  }
  const payouts = text(renderer.root.findByProps({ 'aria-labelledby': 'tv-settlement-heading' }));
  for (const value of ['Onay bekleyen işletme payı', '2.100', 'Onaylanan işletme payı', '87.300', 'Toplam iade tutarı', '500']) {
    assert.ok(payouts.includes(value), `${value} settlement metric must remain visible`);
  }
  assert.match(text(renderer.root.findByProps({ role: 'status' })), /Bağlantı açık/);
  assert.doesNotMatch(JSON.stringify(renderer.toJSON()), /Private Customer Name|private@example\.test|PRIVATE-PICKUP-634981/);
});

test('embedded sales refreshKey updates all sales sections and repeated changes cannot overlap an in-flight request', async (t) => {
  const calls = { stats: 0, settlement: 0, orders: 0 };
  let deferStats = false;
  let finishStats;
  let nextStats = dashboardStats();
  let nextSettlement = settlement();
  let nextOrders = orders();
  const setup = harness({
    getAdminDashboard: () => {
      calls.stats++;
      return deferStats
        ? new Promise(resolve => { finishStats = () => resolve({ stats: nextStats }); })
        : Promise.resolve({ stats: nextStats });
    },
    getSettlementSummary: async () => { calls.settlement++; return { summary: nextSettlement }; },
    getOrders: async () => { calls.orders++; return nextOrders; },
  });
  const renderer = await mount(t, setup, { embedded: true, refreshKey: 0 });
  const { TvDashboard } = setup.load('components/admin/TvDashboard.tsx');
  const updateKey = async refreshKey => {
    await act(async () => { renderer.update(React.createElement(TvDashboard, { embedded: true, refreshKey })); });
    await setup.fireTimers(0);
  };
  assert.deepEqual(calls, { stats: 1, settlement: 1, orders: 1 });
  deferStats = true;
  nextStats = dashboardStats({ todayRevenue: 5678, todayOrders: 28 });
  nextSettlement = settlement({ held: 7200 });
  nextOrders = orders('Yenilenen Satış Paketi');
  await updateKey(1);
  assert.deepEqual(calls, { stats: 2, settlement: 2, orders: 2 });
  assert.match(text(renderer.root.findByProps({ role: 'status' })), /güncelleniyor/);
  assert.match(text(renderer.root.findByProps({ 'aria-label': 'Platform metrikleri' })), /1\.230/);
  await updateKey(2);
  await updateKey(3);
  assert.deepEqual(calls, { stats: 2, settlement: 2, orders: 2 }, 'parent refreshes must not start concurrent requests');
  await act(async () => { finishStats(); });
  assert.match(text(renderer.root.findByProps({ 'aria-label': 'Platform metrikleri' })), /5\.678/);
  assert.match(text(renderer.root.findByProps({ 'aria-labelledby': 'tv-settlement-heading' })), /7\.200/);
  assert.match(text(renderer.root.findByProps({ 'aria-labelledby': 'tv-orders-heading' })), /Yenilenen Satış Paketi/);
  assert.match(text(renderer.root.findByProps({ role: 'status' })), /Bağlantı açık/);
  deferStats = false;
  nextStats = dashboardStats({ todayRevenue: 9999 });
  await updateKey(4);
  assert.deepEqual(calls, { stats: 3, settlement: 3, orders: 3 });
  assert.match(text(renderer.root.findByProps({ 'aria-label': 'Platform metrikleri' })), /9\.999/);
});
