// PM2 process configuration - non-Docker (bare-metal) deployment path.
//
// Usage:
//   pm2 start ecosystem.config.js --env production
//   pm2 save && pm2 startup   # persist across reboots
//   pm2 logs bitir-yemek
//
// IMPORTANT: instances is 1 (fork mode), NOT cluster. This app keeps state in
// process memory that does NOT work across multiple instances:
//   - express-rate-limit uses an in-memory store (per-process counters)
//   - node-cron jobs would run once per instance, causing duplicate work
// Scaling horizontally would require a shared rate-limit store (e.g. Redis) and
// a single cron owner. Keep this at 1 for the single-VPS deployment.

module.exports = {
  apps: [
    {
      name: 'bitir-yemek',
      script: 'src/server.js',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,

      // Restart if the process exceeds this memory ceiling (guards against leaks).
      max_memory_restart: '512M',

      // Back off restart storms.
      min_uptime: '10s',
      max_restarts: 10,
      restart_delay: 5000,

      env: {
        NODE_ENV: 'production',
        PORT: 3000,
      },

      // Logs (ensure the logs/ directory exists and is writable).
      error_file: './logs/pm2-error.log',
      out_file: './logs/pm2-out.log',
      merge_logs: true,
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    },
  ],
};
