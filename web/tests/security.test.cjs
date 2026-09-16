/* eslint-disable @typescript-eslint/no-require-imports -- Node test runner uses CommonJS for the TypeScript VM harness. */
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('typescript');
const { NextRequest } = require('next/server');

function load(file, mocks = {}) {
  const output = ts.transpileModule(fs.readFileSync(path.join(__dirname, '../src', file), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  const loadedModule = { exports: {} };
  vm.runInNewContext(output, { module: loadedModule, exports: loadedModule.exports,
    require: name => Object.hasOwn(mocks, name) ? mocks[name] : require(name),
    process: { env: {} }, URL, Headers, Request, TextDecoder, Uint8Array, ArrayBuffer, setTimeout,
  });
  return loadedModule.exports;
}

test('redirect targets cannot escape the local origin through slashes, backslashes or controls', () => {
  const { safeLocalPath } = load('lib/auth/safe-redirect.ts');
  for (const target of ['//evil.test', '/\\evil.test', '/\n/evil.test', '/\t/evil.test', 'https://evil.test', 'javascript:alert(1)']) {
    assert.equal(safeLocalPath(target), '/panel');
  }
  assert.equal(safeLocalPath('/admin/siparisler?page=2'), '/admin/siparisler?page=2');
  assert.equal(safeLocalPath(undefined, '/admin'), '/admin');
});

test('cookie-authenticated writes require the exact web origin', () => {
  const { middleware } = load('middleware.ts');
  const send = origin => middleware(new NextRequest('https://portal.example/api/auth/logout', {
    method: 'POST', headers: origin ? { origin, cookie: 'bg_rt=session' } : { cookie: 'bg_rt=session' },
  }));
  assert.equal(send('https://portal.example').status, 200);
  assert.equal(send('https://evil.example').status, 403);
  assert.equal(send('https://sibling.portal.example').status, 403);
  assert.equal(send(null).status, 403);
});

test('login page does not loop back to panel merely because an expired cookie exists', () => {
  const { middleware } = load('middleware.ts');
  const response = middleware(new NextRequest('https://portal.example/giris?next=/admin', { headers: { cookie: 'bg_rt=expired' } }));
  assert.equal(response.status, 200);
  assert.equal(response.headers.has('location'), false);
});

test('same-origin requests work behind the HTTPS reverse proxy', () => {
  const { middleware } = load('middleware.ts');
  const req = new NextRequest('http://web:3000/api/auth/login', { method: 'POST', headers: {
    host: 'portal.example', 'x-forwarded-proto': 'https', origin: 'https://portal.example',
  } });
  assert.equal(middleware(req).status, 200);
});

test('body limits apply to a streaming request without Content-Length', async () => {
  const { readLimitedBody } = load('lib/api/request-body.ts');
  let cancelled = false;
  const stream = new ReadableStream({
    start(controller) { controller.enqueue(new Uint8Array(50)); controller.enqueue(new Uint8Array(51)); },
    cancel() { cancelled = true; },
  });
  const req = new Request('https://portal.example/api/auth/login', { method: 'POST', body: stream, duplex: 'half' });
  await assert.rejects(readLimitedBody(req, 100));
  assert.equal(cancelled, true);
});

test('concurrent BFF requests rotate a refresh token once and each receive the new cookies', async () => {
  let backendCalls = 0;
  let cleared = 0;
  const sessions = [];
  const { refreshSession } = load('lib/auth/refresh.ts', {
    'server-only': {},
    '@/lib/api/client': { callBackendJson: async () => {
      backendCalls++;
      await new Promise(resolve => setTimeout(resolve, 15));
      return Response.json({ accessToken: 'fresh-access', refreshToken: 'fresh-refresh' });
    } },
    '@/lib/auth/session': {
      getRefreshToken: async () => 'old-refresh',
      setSession: async (...tokens) => sessions.push(tokens),
      clearSession: async () => { cleared++; },
    },
  });
  const result = await Promise.all([refreshSession(), refreshSession(), refreshSession()]);
  assert.deepEqual(result, ['fresh-access', 'fresh-access', 'fresh-access']);
  assert.equal(backendCalls, 1);
  assert.equal(sessions.length, 3);
  assert.equal(cleared, 0);
});

test('a transient backend failure does not delete the web session', async () => {
  let cleared = false;
  const { refreshSession } = load('lib/auth/refresh.ts', {
    'server-only': {},
    '@/lib/api/client': { callBackendJson: async () => new Response('{}', { status: 503 }) },
    '@/lib/auth/session': { getRefreshToken: async () => 'existing-refresh', clearSession: async () => { cleared = true; } },
  });
  assert.equal(await refreshSession(), null);
  assert.equal(cleared, false);
});
