const runtimeMetrics = require('../services/runtimeMetrics');

const getRuntimeMetrics = (req, res) => {
  res.set('Cache-Control', 'no-store');
  res.json({ runtime: runtimeMetrics.snapshot() });
};

module.exports = { getRuntimeMetrics };
