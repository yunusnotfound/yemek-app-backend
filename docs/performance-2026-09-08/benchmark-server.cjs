// Local-only instrumentation: loads the real Express app in production mode.
const { monitorEventLoopDelay, performance } = require('node:perf_hooks');
const { sequelize } = require('../../src/models');
const cache = require('../../src/services/cacheService');
const app = require('../../src/app');
const histogram = monitorEventLoopDelay({ resolution: 10 });
histogram.enable();
let queries = 0, measured = false, sql = [], capture = false, start;
sequelize.addHook('beforeQuery', () => { if (measured) queries++; });
sequelize.options.logging = (statement) => { if (capture) sql.push(statement.replace(/^Executing \([^)]+\): /, '')); };
let server;
process.on('message', async ({ id, op }) => {
  try {
    if (op === 'start') {
      histogram.reset(); queries = 0; sql = []; measured = true;
      start = { time: performance.now(), cpu: process.cpuUsage(), memory: process.memoryUsage() };
      process.send({ id, result: true });
    } else if (op === 'stop') {
      measured = false;
      const cpu = process.cpuUsage(start.cpu), elapsed = performance.now() - start.time;
      process.send({ id, result: { queries, cpuMs: (cpu.user + cpu.system) / 1000,
        cpuOneCorePercent: (cpu.user + cpu.system) / (elapsed * 10),
        rssMiB: process.memoryUsage().rss / 1048576, heapMiB: process.memoryUsage().heapUsed / 1048576,
        eventLoopP95Ms: histogram.percentile(95) / 1e6, eventLoopMaxMs: histogram.max / 1e6 } });
    } else if (op === 'capture') {
      sql = []; capture = true; process.send({ id, result: true });
    } else if (op === 'sql') {
      capture = false; process.send({ id, result: sql });
    } else if (op === 'close') {
      await new Promise(resolve => server.close(resolve));
      await cache.quit(); await sequelize.close(); histogram.disable();
      process.send({ id, result: true }); process.exit(0);
    }
  } catch (error) { process.send({ id, error: error.message }); }
});
(async () => {
  await sequelize.authenticate();
  if (!await cache.ping()) throw new Error('Isolated Redis must be available');
  server = app.listen(0, '127.0.0.1', () => process.send({ ready: true, port: server.address().port }));
})().catch(error => { console.error(error); process.exit(1); });
