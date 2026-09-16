#!/usr/bin/env bash
# Creates and destroys its own local PostgreSQL/Redis instances. No application .env.
set -euo pipefail
perf_root="$(cd "$(dirname "$0")/../.." && pwd)"
perf_dir="$(cd "$(dirname "$0")" && pwd)"
perf_pg_bin="${PERF_PG_BIN:-/opt/homebrew/opt/postgresql@16/bin}"
test -x "$perf_pg_bin/initdb"
command -v redis-server >/dev/null
perf_tmp="$(mktemp -d /tmp/bitir-perf-replay-XXXXXX)"
perf_free_port() {
  node -e 'const s=require("net").createServer();s.listen(0,"127.0.0.1",()=>{console.log(s.address().port);s.close()})'
}
perf_db_port="$(perf_free_port)"
perf_redis_port="$(perf_free_port)"
while [ "$perf_db_port" = "$perf_redis_port" ]; do perf_redis_port="$(perf_free_port)"; done
perf_cleanup() {
  if [ -f "$perf_tmp/redis.pid" ]; then kill "$(cat "$perf_tmp/redis.pid")" 2>/dev/null || true; fi
  "$perf_pg_bin/pg_ctl" -D "$perf_tmp/pg" -m fast stop >/dev/null 2>&1 || true
  rm -r "$perf_tmp"
}
trap perf_cleanup EXIT
trap 'exit 130' INT TERM
"$perf_pg_bin/initdb" -D "$perf_tmp/pg" -U postgres --auth=trust --no-locale -E UTF8 > "$perf_tmp/initdb.log"
"$perf_pg_bin/pg_ctl" -D "$perf_tmp/pg" -l "$perf_tmp/postgres.log" -o "-p $perf_db_port -h 127.0.0.1 -k $perf_tmp" start
redis-server --bind 127.0.0.1 --port "$perf_redis_port" --save '' --appendonly no --daemonize yes --pidfile "$perf_tmp/redis.pid" --logfile "$perf_tmp/redis.log"
cd "$perf_root"
unset DATABASE_URL RESEND_API_KEY IYZICO_API_KEY IYZICO_SECRET_KEY SENTRY_DSN GOOGLE_MAPS_API_KEY
export PERF_DB_PORT="$perf_db_port" PERF_REDIS_PORT="$perf_redis_port"
export DB_HOST=127.0.0.1 DB_PORT="$perf_db_port" DB_USER=postgres DB_PASSWORD=performance-test DB_SSL=false
export TEST_DB_NAME=bitir_performance_test REDIS_URL="redis://127.0.0.1:$perf_redis_port" NODE_ENV=test
npm test -- --json --outputFile="$perf_dir/backend-tests.json" > "$perf_dir/backend-tests.log" 2>&1
node "$perf_dir/benchmark.cjs" > "$perf_dir/benchmark.log" 2>&1
node "$perf_dir/followup.cjs" > "$perf_dir/followup.log" 2>&1
node "$perf_dir/redis-outage.cjs" > "$perf_dir/redis-outage.log" 2>&1
echo "Results: $perf_dir"
