const { monitorEventLoopDelay, performance } = require('node:perf_hooks');

const WINDOW_MS = 15 * 60 * 1000;
const MAX_SAMPLES = 10000;
const API_BASES = new Set([
  '/api/auth', '/api/users', '/api/categories', '/api/businesses', '/api/packages',
  '/api/orders', '/api/payments', '/api/cards', '/api/reviews', '/api/favorites',
  '/api/notifications', '/api/coupons', '/api/admin', '/api/maps',
  '/api/business-dashboard', '/api/upload',
]);
const MONITORING_READS = new Set([
  '/api/health', '/api/admin/dashboard', '/api/admin/settlement/summary',
  '/api/admin/orders', '/api/admin/operations/runtime',
]);
const METHODS = new Set(['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS', 'CONNECT', 'TRACE']);

function percentile(sorted, fraction) {
  return sorted.length ? sorted[Math.max(0, Math.ceil(sorted.length * fraction) - 1)] : null;
}

function round(value) {
  return Math.round(value * 100) / 100;
}

function apiBase(pathname) {
  // Classify only a fixed mount name. No user-controlled suffix is retained.
  const base = pathname.split('/').slice(0, 3).join('/');
  return API_BASES.has(base) ? base : '/api';
}

function routeLabel(req, initialBase) {
  const template = req.route?.path;
  // Express route templates come from application code, never req.url/path.
  // Reject regex/array routes and unusual literals rather than emitting input.
  if (typeof template !== 'string' || template.length > 160 ||
      !/^\/(?:[A-Za-z][A-Za-z0-9-]*|:[A-Za-z][A-Za-z0-9_]*|\/)*$/.test(template)) {
    return 'unmatched';
  }
  const base = API_BASES.has(req.baseUrl) ? req.baseUrl : initialBase;
  const label = template.startsWith('/api/') ? template : `${base}${template}`;
  return label.replace(/\/{2,}/g, '/').replace(/\/$/, '') || '/api';
}

/** Bounded, process-local telemetry. Injection is for deterministic unit tests. */
function createRuntimeMetrics({
  now = () => performance.now(),
  wallNow = () => Date.now(),
  processInfo = process,
  histogram = monitorEventLoopDelay({ resolution: 20 }),
  maxSamples = MAX_SAMPLES,
} = {}) {
  const capacity = Math.max(1, Math.min(MAX_SAMPLES, Math.floor(maxSamples) || MAX_SAMPLES));
  const samples = new Array(capacity);
  const observedSince = now();
  const startedAt = new Date(wallNow() - processInfo.uptime() * 1000).toISOString();
  let head = 0;
  let size = 0;
  let inFlight = 0;
  let droppedSamples = 0;
  let retainedSince = observedSince;
  histogram.enable(); // Node's histogram does not keep the event loop alive.

  function expire(time) {
    while (size && samples[head].at <= time - WINDOW_MS) {
      samples[head] = undefined;
      head = (head + 1) % capacity;
      size--;
    }
  }

  function record(sample) {
    expire(sample.at);
    if (size === capacity) {
      retainedSince = samples[head].at;
      samples[head] = undefined;
      head = (head + 1) % capacity;
      size--;
      droppedSamples++;
    }
    samples[(head + size) % capacity] = sample;
    size++;
  }

  function middleware(req, res, next) {
    // Express mounts are case-insensitive by default; classification matches it.
    const pathname = String(req.path || '').toLowerCase().replace(/\/$/, '') || '/';
    if (!(pathname === '/api' || pathname.startsWith('/api/')) ||
        (req.method === 'GET' && MONITORING_READS.has(pathname))) return next();

    const started = now();
    const initialBase = apiBase(pathname);
    const method = METHODS.has(req.method) ? req.method : 'OTHER';
    const profileProbe = method === 'GET' && pathname === '/api/users/profile' &&
      req.get('x-operations-probe') === '1';
    let completed = false;
    inFlight++;

    function complete(status) {
      if (completed) return;
      completed = true;
      inFlight--;
      res.removeListener('finish', finish);
      res.removeListener('close', close);
      req.removeListener('aborted', aborted);
      // Only a successfully authenticated admin's exact monitoring profile read
      // is excluded. A supplied header cannot hide other routes/users/errors.
      if (profileProbe && req.user?.role === 'admin' && status < 400) return;
      const time = now();
      record({ at: time, duration: Math.max(0, time - started), status, method, route: routeLabel(req, initialBase) });
    }
    const finish = () => complete(res.statusCode);
    const close = () => complete(res.writableFinished ? res.statusCode : 499);
    const aborted = () => complete(499);
    res.once('finish', finish);
    res.once('close', close);
    req.once('aborted', aborted);
    return next();
  }

  function snapshot() {
    const time = now();
    expire(time);
    const statusCounts = { success: 0, clientError: 0, serverError: 0 };
    const durations = [];
    const routes = new Map();
    for (let index = 0; index < size; index++) {
      const sample = samples[(head + index) % capacity];
      statusCounts[sample.status >= 500 ? 'serverError' : sample.status >= 400 ? 'clientError' : 'success']++;
      durations.push(sample.duration);
      const key = `${sample.method} ${sample.route}`;
      if (!routes.has(key)) routes.set(key, { method: sample.method, route: sample.route, durations: [], errors: 0 });
      const route = routes.get(key);
      route.durations.push(sample.duration);
      if (sample.status >= 500) route.errors++;
    }
    durations.sort((a, b) => a - b);
    const windowSeconds = Math.max(1, Math.min(WINDOW_MS / 1000, (time - Math.max(observedSince, retainedSince)) / 1000));
    const memory = processInfo.memoryUsage();
    const loopP95 = histogram.count > 0 ? histogram.percentile(95) / 1e6 : null;
    const slowRoutes = [...routes.values()].map(route => ({
      method: route.method,
      route: route.route,
      requests: route.durations.length,
      p95Ms: round(percentile(route.durations.sort((a, b) => a - b), 0.95)),
      errors: route.errors,
    })).sort((a, b) => b.p95Ms - a.p95Ms || b.requests - a.requests).slice(0, 10);

    return {
      startedAt, sampledAt: new Date(wallNow()).toISOString(),
      uptimeSeconds: processInfo.uptime(), nodeVersion: processInfo.version,
      windowSeconds: round(windowSeconds), requests: size, requestsPerMinute: round(size * 60 / windowSeconds),
      statusCounts, errorRatePercent: size ? round(statusCounts.serverError * 100 / size) : null,
      p50Ms: size ? round(percentile(durations, 0.5)) : null,
      p95Ms: size ? round(percentile(durations, 0.95)) : null,
      maxMs: size ? round(durations[durations.length - 1]) : null,
      inFlight, heapUsedBytes: memory.heapUsed, heapTotalBytes: memory.heapTotal, rssBytes: memory.rss,
      eventLoopP95Ms: Number.isFinite(loopP95) ? round(loopP95) : null,
      // The histogram is cumulative since telemetry initialization, not the request window.
      eventLoopWindowSeconds: Math.max(0, round((time - observedSince) / 1000)),
      droppedSamples, slowRoutes,
    };
  }

  return { middleware, snapshot, close: () => histogram.disable() };
}

const runtimeMetrics = createRuntimeMetrics();
module.exports = { ...runtimeMetrics, createRuntimeMetrics };
