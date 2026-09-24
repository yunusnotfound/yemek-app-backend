/* eslint-disable @typescript-eslint/no-require-imports -- Node test runner uses a TypeScript VM harness. */
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('typescript');

function load(file, mocks = {}, globals = {}) {
  const filename = path.join(__dirname, '../src', file);
  const output = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, esModuleInterop: true },
  }).outputText;
  const loadedModule = { exports: {} };
  vm.runInNewContext(output, {
    module: loadedModule, exports: loadedModule.exports,
    require: name => Object.hasOwn(mocks, name) ? mocks[name] : require(name),
    process: { env: {}, cwd: () => '/application/web' }, URL, Headers, Request, Response, AbortSignal,
    setTimeout, clearTimeout, ...globals,
  }, { filename });
  return loadedModule.exports;
}

function snapshot(overrides = {}) {
  return {
    collectedAt: '2026-09-24T17:00:00.000Z', collectionMs: 2500, source: 'Canlı VPS', partialErrors: [],
    host: null, containers: [], database: null, redis: null, http: { api: null, web: null, tls: null },
    logs: null, backups: null, release: null, integrations: null, queues: null, runtime: null, runtimeError: null,
    ...overrides,
  };
}

const runtime = { requests: 31, sampledAt: '2026-09-24T17:00:00.000Z', nodeVersion: 'v24.0.0' };

function collectorHarness(options = {}) {
  let now = Date.parse('2026-09-24T17:00:00Z');
  const executions = [], backendCalls = [], reads = [], completions = [];
  let currentSnapshot = snapshot();
  let failure = null;
  let runtimeResponse = () => Response.json({ runtime });
  class Clock extends Date { static now() { return now; } }
  const env = { OPS_SSH_HOST: 'vps.example.test', OPS_SSH_USER: 'deploy', OPS_SSH_KEY: '/keys/operations', ...options.env };
  const loadedModule = load('lib/operations/collector.ts', {
    'server-only': {},
    'node:fs/promises': { readFile: async (...args) => { reads.push(args); return '# trusted read-only collector\n'; } },
    'node:child_process': { execFile: (file, args, config, callback) => {
      const execution = { file, args: Array.from(args), config, script: null };
      executions.push(execution);
      const complete = () => callback(failure, failure ? '' : JSON.stringify(currentSnapshot), failure ? 'secret-stderr' : '');
      if (options.defer) completions.push(complete);
      else queueMicrotask(complete);
      return { stdin: { on: () => {}, end: script => { execution.script = script; } } };
    } },
    '@/lib/api/client': { callBackend: async (route, config) => { backendCalls.push({ route, config }); return runtimeResponse(); } },
  }, { Date: Clock, process: { env, cwd: () => '/application/web' } });
  return {
    ...loadedModule, executions, backendCalls, reads, env,
    advance: milliseconds => { now += milliseconds; },
    setSnapshot: value => { currentSnapshot = value; },
    fail: value => { failure = value; },
    setRuntime: value => { runtimeResponse = value; },
    complete: () => { for (const done of completions.splice(0)) done(); },
  };
}

function routeHarness(options = {}) {
  const profileCalls = [], collectorCalls = [];
  const timeouts = [];
  let refreshCalls = 0;
  let token = options.token;
  let role = options.role || 'admin';
  let profileResponse = options.profileResponse;
  class OperationsUnavailable extends Error {}
  const collector = options.collector || {
    OperationsUnavailable,
    getOperationsSnapshot: async value => { collectorCalls.push(value); return snapshot(); },
  };
  const route = load('app/api/admin/operations/route.ts', {
    '@/lib/auth/session': { getAccessToken: async () => token },
    '@/lib/auth/refresh': { refreshSession: async () => { refreshCalls++; return options.refreshed || null; } },
    '@/lib/api/client': { callBackend: async (url, config) => {
      profileCalls.push({ url, config });
      return profileResponse ? profileResponse(url, config) : Response.json({ user: { role } });
    } },
    '@/lib/operations/collector': collector,
  }, { AbortSignal: { timeout: milliseconds => { timeouts.push(milliseconds); return AbortSignal.timeout(milliseconds); } } });
  return { ...route, profileCalls, collectorCalls, timeouts, get refreshCalls() { return refreshCalls; },
    setRole: value => { role = value; }, setToken: value => { token = value; },
    setProfile: value => { profileResponse = value; } };
}

function assertPrivate(response) {
  assert.equal(response.headers.get('cache-control'), 'private, no-store');
  assert.equal(response.headers.get('vary'), 'Cookie');
}

test('operations route refuses anonymous sessions before touching the collector', async () => {
  const app = routeHarness();
  const response = await app.GET();
  assert.equal(response.status, 401);
  assert.equal(app.profileCalls.length, 0);
  assert.equal(app.collectorCalls.length, 0);
  assert.equal(app.refreshCalls, 1);
  assertPrivate(response);
});

test('operations route refuses non-admin users and backend authorization failures without collecting', async () => {
  for (const setup of [
    { token: 'customer-token', role: 'customer', expected: 403 },
    { token: 'admin-token', profileResponse: () => Response.json({ message: 'unavailable' }, { status: 503 }), expected: 503 },
  ]) {
    const app = routeHarness(setup);
    const response = await app.GET();
    assert.equal(response.status, setup.expected);
    assert.equal(app.profileCalls.length, 1);
    assert.equal(app.collectorCalls.length, 0);
    assert.equal(app.refreshCalls, 0);
    assertPrivate(response);
  }
});

test('operations route refreshes an expired access token and rechecks admin authorization', async () => {
  const app = routeHarness({ token: 'expired', refreshed: 'fresh-admin', profileResponse: (url, { token }) =>
    token === 'expired' ? Response.json({}, { status: 401 }) : Response.json({ user: { role: 'admin' } }) });
  const response = await app.GET();
  assert.equal(response.status, 200);
  assert.equal(app.refreshCalls, 1);
  assert.deepEqual(app.profileCalls.map(call => call.config.token), ['expired', 'fresh-admin']);
  assert.deepEqual(app.collectorCalls, ['fresh-admin']);
  assert.deepEqual(app.timeouts, [5000, 5000]);
  for (const call of app.profileCalls) {
    assert.equal(call.url, '/users/profile');
    assert.equal(call.config.headers['x-operations-probe'], '1');
  }
  assertPrivate(response);
});

test('a populated shared operations cache never bypasses live per-request admin authorization', async () => {
  const collector = collectorHarness();
  let collectionCalls = 0;
  const app = routeHarness({ token: 'admin-token', collector: {
    ...collector,
    getOperationsSnapshot: token => { collectionCalls++; return collector.getOperationsSnapshot(token); },
  } });
  for (let attempt = 0; attempt < 2; attempt++) {
    const response = await app.GET();
    assert.equal(response.status, 200);
    assertPrivate(response);
  }
  assert.equal(collectionCalls, 2);
  assert.equal(collector.executions.length, 1);
  assert.equal(app.profileCalls.length, 2);
  app.setRole('customer');
  assert.equal((await app.GET()).status, 403);
  assert.equal(collectionCalls, 2);
  app.setToken(undefined);
  assert.equal((await app.GET()).status, 401);
  assert.equal(collectionCalls, 2);
});

test('collector process failure never exposes stderr, command, keys or tokens through the route', async () => {
  const collector = collectorHarness();
  const error = Object.assign(new Error('ssh /keys/operations PRIVATE-TOKEN'), { stderr: 'password=PRIVATE-SECRET' });
  collector.fail(error);
  collector.setRuntime(() => Response.json({}, { status: 503 }));
  const app = routeHarness({ token: 'PRIVATE-TOKEN', collector });
  const response = await app.GET();
  assert.equal(response.status, 503);
  const body = await response.text();
  for (const secret of ['PRIVATE-TOKEN', 'PRIVATE-SECRET', '/keys/operations', 'stderr']) assert.equal(body.includes(secret), false);
  assertPrivate(response);
});

test('concurrent operations collections coalesce and the snapshot is cached for exactly 15 seconds', async () => {
  const app = collectorHarness({ defer: true });
  const pending = [app.getOperationsSnapshot('admin-one'), app.getOperationsSnapshot('admin-two')];
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(app.executions.length, 1);
  assert.equal(app.backendCalls.length, 1);
  app.complete();
  const [first, second] = await Promise.all(pending);
  assert.equal(first, second);
  assert.equal(first.runtime.requests, runtime.requests);
  app.advance(14999);
  assert.equal(await app.getOperationsSnapshot('admin-three'), first);
  assert.equal(app.executions.length, 1);
  app.advance(1);
  const renewed = app.getOperationsSnapshot('admin-four');
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(app.executions.length, 2);
  assert.equal(app.backendCalls.length, 2);
  app.complete();
  await renewed;
});

test('SSH failure preserves the old host timestamp while merging fresh runtime and an explicit stale warning', async () => {
  const app = collectorHarness();
  const original = await app.getOperationsSnapshot('admin');
  app.advance(15000);
  app.fail(new Error('network secret details'));
  const freshRuntime = { ...runtime, sampledAt: '2026-09-24T17:00:15.000Z', requests: 45 };
  app.setRuntime(() => Response.json({ runtime: freshRuntime }));
  const stale = await app.getOperationsSnapshot('admin');
  assert.equal(stale.collectedAt, original.collectedAt);
  assert.equal(stale.runtime.sampledAt, freshRuntime.sampledAt);
  assert.equal(stale.runtime.requests, 45);
  assert.equal(stale.partialErrors.length, 1);
  assert.match(stale.partialErrors[0], /eski ölçümler/);
  assert.equal(JSON.stringify(stale).includes('network secret details'), false);
  app.advance(15000);
  const stillStale = await app.getOperationsSnapshot('admin');
  assert.equal(stillStale.partialErrors.length, 1);
  assert.equal(stillStale.collectedAt, original.collectedAt);
});

test('SSH uses trusted configuration, strict host verification, no shell and a fixed stdin collector', async () => {
  const app = collectorHarness({ env: { OPS_SSH_PORT: '2222' } });
  const token = 'admin-token;$(touch /tmp/never-run)';
  await app.getOperationsSnapshot(token);
  const execution = app.executions[0];
  assert.equal(execution.file, '/usr/bin/ssh');
  for (const setting of ['BatchMode=yes', 'StrictHostKeyChecking=yes', 'IdentitiesOnly=yes', 'ConnectTimeout=5']) {
    assert.ok(execution.args.includes(setting));
  }
  assert.deepEqual(execution.args.slice(-3), ['2222', 'deploy@vps.example.test', 'python3 -']);
  assert.equal(execution.config.shell, undefined);
  assert.equal(execution.config.timeout, 18000);
  assert.equal(execution.config.maxBuffer, 512 * 1024);
  assert.equal(execution.script, '# trusted read-only collector\n');
  assert.deepEqual(app.reads, [['/application/web/src/lib/operations/collect-operations.py', 'utf8']]);
  assert.equal(JSON.stringify(execution).includes(token), false);
  assert.equal(app.backendCalls[0].route, '/admin/operations/runtime');
  assert.equal(app.backendCalls[0].config.token, token);
  assert.ok(app.backendCalls[0].config.signal instanceof AbortSignal);
});

test('missing or invalid SSH configuration cannot start a subprocess but usable runtime stays visible', async () => {
  for (const env of [
    { OPS_SSH_HOST: undefined }, { OPS_SSH_USER: undefined }, { OPS_SSH_KEY: undefined },
    { OPS_SSH_HOST: 'vps;unsafe' }, { OPS_SSH_USER: '-oProxyCommand=unsafe' },
    { OPS_SSH_KEY: 'relative-key' }, { OPS_SSH_PORT: '0' }, { OPS_SSH_PORT: '65536' }, { OPS_SSH_PORT: '22.5' },
  ]) {
    const app = collectorHarness({ env });
    const result = await app.getOperationsSnapshot('admin');
    assert.equal(result.host, null);
    assert.equal(result.source, 'API çalışma zamanı');
    assert.equal(result.runtime.requests, 31);
    assert.equal(result.partialErrors.length, 1);
    assert.equal(app.executions.length, 0);
    assert.equal(app.reads.length, 0);
  }
});

test('runtime metrics require the runtime envelope and unavailable metrics leave host data usable', async () => {
  const valid = collectorHarness();
  assert.equal((await valid.getOperationsSnapshot('admin')).runtime.requests, 31);
  for (const reply of [
    () => Response.json(runtime),
    () => Response.json({ runtime: { sampledAt: runtime.sampledAt } }),
    () => Response.json({}, { status: 404 }),
    () => Response.json({}, { status: 503 }),
  ]) {
    const app = collectorHarness();
    app.setRuntime(reply);
    const value = await app.getOperationsSnapshot('admin');
    assert.equal(value.source, 'Canlı VPS');
    assert.equal(value.runtime, null);
    assert.ok(value.runtimeError);
    assert.equal(value.partialErrors.length, 0);
  }
});

test('malformed SSH output is never accepted as a fresh successful snapshot', async () => {
  for (const value of [{}, snapshot({ collectedAt: 'not-a-date' }), snapshot({ containers: null })]) {
    const app = collectorHarness();
    app.setSnapshot(value);
    const result = await app.getOperationsSnapshot('admin');
    assert.equal(result.host, null);
    assert.equal(result.source, 'API çalışma zamanı');
    assert.equal(result.partialErrors.length, 1);
  }
});

test('the first SSH outage returns explicit null host sections and fresh runtime without exposing the process error', async () => {
  const app = collectorHarness();
  app.fail(new Error('PRIVATE-SSH-ERROR'));
  const result = await app.getOperationsSnapshot('admin');
  assert.equal(result.source, 'API çalışma zamanı');
  assert.equal(result.runtime.requests, 31);
  for (const section of ['host', 'database', 'redis', 'logs', 'backups', 'release', 'integrations', 'queues']) {
    assert.equal(result[section], null);
  }
  assert.equal(result.containers.length, 0);
  assert.deepEqual(JSON.parse(JSON.stringify(result.http)), { api: null, web: null, tls: null });
  assert.match(result.partialErrors[0], /yalnızca API/);
  assert.equal(JSON.stringify(result).includes('PRIVATE-SSH-ERROR'), false);
  app.advance(15000);
  app.fail(null);
  app.setSnapshot(snapshot({ collectedAt: '2026-09-24T17:00:15.000Z' }));
  const restored = await app.getOperationsSnapshot('admin');
  assert.equal(restored.source, 'Canlı VPS');
  assert.equal(restored.partialErrors.length, 0);
  assert.equal(restored.collectedAt, '2026-09-24T17:00:15.000Z');
});

test('runtime transport rejection does not discard an independently successful host sample', async () => {
  const app = collectorHarness();
  app.setRuntime(() => { throw new Error('PRIVATE-NETWORK-ERROR'); });
  const result = await app.getOperationsSnapshot('admin');
  assert.equal(result.source, 'Canlı VPS');
  assert.equal(result.collectedAt, snapshot().collectedAt);
  assert.equal(result.runtime, null);
  assert.match(result.runtimeError, /alınamadı/);
  assert.equal(JSON.stringify(result).includes('PRIVATE-NETWORK-ERROR'), false);
});

test('both sources unavailable on first load yields a sanitized unavailable error', async () => {
  const app = collectorHarness({ env: { OPS_SSH_HOST: undefined } });
  app.setRuntime(() => Response.json({}, { status: 503 }));
  await assert.rejects(app.getOperationsSnapshot('admin'), error => error instanceof app.OperationsUnavailable);
  assert.equal(app.executions.length, 0);
});
