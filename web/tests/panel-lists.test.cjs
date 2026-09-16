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
  const state = { businessId: 'business-a' };
  const cache = new Map();
  const mocks = {
    '@/lib/api/panel': api,
    '@/components/panel/RequireBusiness': {
      RequireBusiness: ({ children }) => children({ id: state.businessId }),
    },
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
      module: loadedModule, exports: loadedModule.exports,
      require: name => {
        if (Object.hasOwn(mocks, name)) return mocks[name];
        if (!name.startsWith('@/')) return require(name);
        const relative = name.slice(2);
        const extension = ['.tsx', '.ts'].find(ext => fs.existsSync(path.join(__dirname, '../src', relative + ext)));
        return load(relative + extension);
      },
      window: { confirm: () => true }, console, URL, setTimeout, clearTimeout,
    }, { filename });
    return loadedModule.exports;
  }
  return { state, load };
}

function text(node) {
  if (typeof node === 'string' || typeof node === 'number') return String(node);
  return node?.children?.map(text).join('') ?? '';
}

function button(renderer, label) {
  const match = renderer.root.findAllByType('button').find(node => text(node) === label);
  assert.ok(match, `Missing button: ${label}`);
  return match;
}

async function click(renderer, label) {
  const target = button(renderer, label);
  assert.notEqual(target.props.disabled, true, `${label} must be enabled`);
  await act(async () => { await target.props.onClick(); });
}

function result(items, page, limit = 50) {
  return {
    data: items.slice((page - 1) * limit, page * limit),
    pagination: { total: items.length, page, limit, totalPages: Math.ceil(items.length / limit) },
  };
}

const item = (id) => ({
  id, title: `Paket ${id}`, status: 'pending', quantity: 1, remainingQuantity: 1,
  originalPrice: 600, discountedPrice: 500, finalPrice: 500, soldQuantity: 0,
  isActive: true, pickupCode: '123456', pickupDate: '2026-09-08',
  pickupStart: '18:00:00', pickupEnd: '20:00:00', createdAt: '2026-09-08T12:00:00Z',
  rating: 5, comment: `Yorum ${id}`, user: { name: `Müşteri ${id}` },
  package: { title: `Paket ${id}`, pickupStart: '18:00:00', pickupEnd: '20:00:00' },
});

for (const [route, method] of [
  ['siparisler', 'getBusinessOrders'],
  ['paketler', 'getBusinessPackages'],
  ['degerlendirmeler', 'getBusinessReviews'],
]) {
  test(`${route}: page 2 is reachable and changing businesses resets to page 1`, async (t) => {
    const calls = [];
    const items = Array.from({ length: 51 }, (_, i) => item(String(i + 1)));
    const { state, load } = harness({
      [method]: async (id, options) => {
        calls.push({ id, ...options });
        return result(items, options.page);
      },
    });
    const Page = load(`app/(dashboard)/panel/${route}/page.tsx`).default;
    let renderer;
    await act(async () => { renderer = create(React.createElement(Page)); });
    t.after(async () => { await act(async () => renderer.unmount()); });
    assert.equal(calls.at(-1).page, 1);
    await click(renderer, 'Sonraki');
    assert.equal(calls.at(-1).page, 2);
    assert.match(text(renderer.root), /Sayfa 2 \/ 2/);
    assert.equal(button(renderer, 'Sonraki').props.disabled, true);
    state.businessId = 'business-b';
    await act(async () => renderer.update(React.createElement(Page)));
    assert.equal(calls.at(-1).id, 'business-b');
    assert.equal(calls.at(-1).page, 1);
  });
}

test('order status can progress from pending to confirmed to delivered without reloading the browser', async (t) => {
  let order = item('paid');
  const transitions = [];
  const { load } = harness({
    getBusinessOrders: async (_, { page }) => result([order], page),
    updateOrderStatus: async (_, status) => {
      transitions.push(status);
      order = { ...order, status };
      return { order };
    },
  });
  const Page = load('app/(dashboard)/panel/siparisler/page.tsx').default;
  let renderer;
  await act(async () => { renderer = create(React.createElement(Page)); });
  t.after(async () => { await act(async () => renderer.unmount()); });
  await click(renderer, 'Onayla');
  await click(renderer, 'Teslim edildi');
  assert.deepEqual(transitions, ['confirmed', 'picked_up']);
});

test('order filters reset pagination and late responses cannot replace the selected filter', async (t) => {
  const calls = [];
  let resolveOldPage;
  const all = Array.from({ length: 51 }, (_, i) => item(String(i + 1)));
  const { load } = harness({
    getBusinessOrders: async (_, options) => {
      calls.push(options);
      if (options.page === 2) return new Promise(resolve => { resolveOldPage = resolve; });
      return result(options.status ? [item('filtre')] : all, options.page);
    },
  });
  const Page = load('app/(dashboard)/panel/siparisler/page.tsx').default;
  let renderer;
  await act(async () => { renderer = create(React.createElement(Page)); });
  t.after(async () => { await act(async () => renderer.unmount()); });
  await click(renderer, 'Sonraki');
  await click(renderer, 'Bekleyen');
  assert.equal(calls.at(-1).page, 1);
  assert.equal(calls.at(-1).status, 'pending');
  await act(async () => resolveOldPage(result(all, 2)));
  assert.match(text(renderer.root), /Paket filtre/);
  assert.doesNotMatch(text(renderer.root), /Paket 51/);
});

test('deleting the only package on the last page returns to the previous valid page', async (t) => {
  let items = Array.from({ length: 51 }, (_, i) => item(String(i + 1)));
  const calls = [];
  const { load } = harness({
    getBusinessPackages: async (_, { page }) => { calls.push(page); return result(items, page); },
    deletePackage: async id => { items = items.filter(pkg => pkg.id !== id); },
  });
  const Page = load('app/(dashboard)/panel/paketler/page.tsx').default;
  let renderer;
  await act(async () => { renderer = create(React.createElement(Page)); });
  t.after(async () => { await act(async () => renderer.unmount()); });
  await click(renderer, 'Sonraki');
  await click(renderer, ' Sil');
  assert.deepEqual(calls, [1, 2, 2, 1]);
  assert.match(text(renderer.root), /Paket 1/);
  assert.doesNotMatch(text(renderer.root), /Henüz paket yok/);
});
