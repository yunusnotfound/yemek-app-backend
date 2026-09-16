const { Worker } = require('node:worker_threads');
const { availableParallelism } = require('node:os');
const path = require('node:path');

const POOL_SIZE = Math.min(4, Math.max(1, availableParallelism() - 1));
const MAX_PENDING_JOBS = 100;
const workers = new Set();
const queue = [];
let closing = false;

const unavailable = () => Object.assign(
  new Error('Giriş işlemleri yoğun, lütfen tekrar deneyin'),
  { statusCode: 503 },
);

const createWorker = () => {
  const worker = new Worker(path.join(__dirname, 'passwordWorker.js'));
  const entry = { worker, job: null, failed: false };
  workers.add(entry);

  const failed = () => {
    if (entry.failed) return;
    entry.failed = true;
    workers.delete(entry);
    entry.job?.reject(unavailable());
    entry.job = null;
    // Drop the failed worker; only queued/new requests start a replacement.
    worker.terminate().catch(() => {});
    if (!closing) dispatch();
  };
  worker.on('error', failed);
  worker.on('exit', failed);
  worker.on('message', ({ result, error }) => {
    const job = entry.job;
    entry.job = null;
    worker.unref();
    if (job) {
      if (error) job.reject(new Error(error));
      else job.resolve(result);
    }
    dispatch();
  });
  worker.unref();
  return entry;
};

const dispatch = () => {
  if (closing) return;
  while (queue.length) {
    let entry = [...workers].find((candidate) => !candidate.job);
    if (!entry && workers.size < POOL_SIZE) {
      try {
        entry = createWorker();
      } catch {
        queue.shift().reject(unavailable());
        continue;
      }
    }
    if (!entry) return;
    entry.job = queue.shift();
    entry.worker.ref();
    entry.worker.postMessage(entry.job.payload);
  }
};

const run = (payload) => new Promise((resolve, reject) => {
  // Bound memory and CPU backlog under login bursts; never weaken hash cost.
  if (closing || queue.length >= MAX_PENDING_JOBS) return reject(unavailable());
  queue.push({ payload, resolve, reject });
  dispatch();
});

const close = async () => {
  closing = true;
  for (const job of queue.splice(0)) job.reject(unavailable());
  const pending = [...workers].map((entry) => {
    entry.failed = true;
    entry.job?.reject(unavailable());
    entry.job = null;
    return entry.worker.terminate();
  });
  workers.clear();
  await Promise.allSettled(pending);
  closing = false;
};

module.exports = {
  hash: (password) => run({ operation: 'hash', password }),
  compare: (password, hash) => run({ operation: 'compare', password, hash }),
  close,
};
