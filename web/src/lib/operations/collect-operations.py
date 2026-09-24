#!/usr/bin/env python3
"""Read-only, bounded VPS snapshot. Execute over SSH with `python3 -`.

Only explicit aggregates leave this process. Environment values, credentials,
SQL text/activity details, log messages, user rows and network addresses never do.
"""
import concurrent.futures
import datetime as dt
import json
import os
import re
import socket
import ssl
import subprocess
import time
import urllib.error
import urllib.request

REPO = "/home/deploy/bitir-yemek"
SERVICES = ("app", "web", "db", "redis")
CONTAINERS = {service: "bitir-yemek-" + service + "-1" for service in SERVICES}
COMMAND_TIMEOUT = 6


def utc(timestamp=None):
    value = dt.datetime.now(dt.timezone.utc) if timestamp is None else dt.datetime.fromtimestamp(timestamp, dt.timezone.utc)
    return value.isoformat().replace("+00:00", "Z")


def command(args, stdin=None, timeout=COMMAND_TIMEOUT, check=True):
    result = subprocess.run(args, input=stdin, capture_output=True, text=True, timeout=timeout)
    if check and result.returncode:
        # Never forward stderr: database/Redis clients can include credentials.
        raise RuntimeError("command failed")
    return result


def resource(total, used):
    return {"totalBytes": total, "usedBytes": max(0, used), "percent": round(100 * max(0, used) / total, 2) if total else 0}


def cpu_ticks():
    with open("/proc/stat", encoding="utf-8") as handle:
        # guest/guest_nice are already included in user/nice.
        ticks = list(map(int, handle.readline().split()[1:9]))
    return sum(ticks), ticks[3] + ticks[4]


def collect_host():
    # Avoid measuring only the short docker/client startup burst from this
    # collector's parallel fan-out. The sampling interval itself remains 0.2s.
    time.sleep(1)
    start_total, start_idle = cpu_ticks()
    time.sleep(0.2)
    end_total, end_idle = cpu_ticks()
    mem = {}
    with open("/proc/meminfo", encoding="utf-8") as handle:
        for line in handle:
            key, value = line.split(":", 1)
            mem[key] = int(value.split()[0]) * 1024
    disk = os.statvfs("/")
    disk_total = disk.f_blocks * disk.f_frsize
    # Matches df usage: reserved blocks aren't counted as available.
    disk_used = (disk.f_blocks - disk.f_bfree) * disk.f_frsize
    network_rx = network_tx = 0
    for name in os.listdir("/sys/class/net"):
        if name == "lo" or name.startswith(("docker", "veth", "br-", "virbr")):
            continue
        if not os.path.exists("/sys/class/net/" + name + "/device"):
            continue
        with open("/sys/class/net/" + name + "/statistics/rx_bytes", encoding="utf-8") as handle:
            network_rx += int(handle.read())
        with open("/sys/class/net/" + name + "/statistics/tx_bytes", encoding="utf-8") as handle:
            network_tx += int(handle.read())
    with open("/proc/uptime", encoding="utf-8") as handle:
        uptime = float(handle.read().split()[0])
    return {"cpuCores": os.cpu_count() or 1,
            "cpuPercent": round(100 * (1 - (end_idle - start_idle) / (end_total - start_total)), 2) if end_total > start_total else 0,
            "loadAverage": list(os.getloadavg()), "uptimeSeconds": uptime,
            "memory": resource(mem["MemTotal"], mem["MemTotal"] - mem["MemAvailable"]),
            "swap": resource(mem["SwapTotal"], mem["SwapTotal"] - mem["SwapFree"]),
            "disk": resource(disk_total, disk_used), "kernel": os.uname().release,
            "networkRxBytes": network_rx, "networkTxBytes": network_tx}


def bytes_value(text):
    match = re.fullmatch(r"\s*([\d.]+)\s*([kKMGTPE]?i?B)\s*", text)
    if not match:
        return None
    units = {"B": 1, "kB": 1000, "KB": 1000, "MB": 1000**2, "GB": 1000**3,
             "TB": 1000**4, "PB": 1000**5, "EB": 1000**6,
             "KiB": 1024, "MiB": 1024**2, "GiB": 1024**3, "TiB": 1024**4,
             "PiB": 1024**5, "EiB": 1024**6}
    return round(float(match[1]) * units[match[2]])


def percent_value(text):
    try:
        return float(text.rstrip("%"))
    except (ValueError, AttributeError):
        return None


def collect_containers():
    inspected = json.loads(command(["docker", "inspect", *CONTAINERS.values()]).stdout)
    stats_error = False
    try:
        stats = {item["Name"]: item for item in map(json.loads, command([
            "docker", "stats", "--no-stream", "--format", "{{json .}}", *CONTAINERS.values()
        ]).stdout.splitlines())}
    except Exception:
        stats, stats_error = {}, True
    image_dates = {}
    try:
        images = json.loads(command(["docker", "image", "inspect", *{obj["Image"] for obj in inspected}]).stdout)
        image_dates = {obj["Id"]: obj["Created"] for obj in images}
    except Exception:
        pass
    output = []
    for item in inspected:
        name = item["Name"].lstrip("/")
        service = next((key for key, value in CONTAINERS.items() if value == name), None)
        if not service:
            continue
        state, metrics = item["State"], stats.get(name, {})
        memory_parts = metrics.get("MemUsage", "").split(" / ")
        network_parts = metrics.get("NetIO", "").split(" / ")
        output.append({"service": service, "state": state["Status"],
                       "health": state.get("Health", {}).get("Status", "unknown"),
                       "restarts": item["RestartCount"], "startedAt": state["StartedAt"],
                       "imageId": item["Image"], "imageCreatedAt": image_dates.get(item["Image"]),
                       "cpuPercent": percent_value(metrics.get("CPUPerc")),
                       "memoryUsedBytes": bytes_value(memory_parts[0]) if len(memory_parts) == 2 else None,
                       "memoryLimitBytes": item["HostConfig"]["Memory"] or None,
                       "memoryPercent": percent_value(metrics.get("MemPerc")),
                       "networkRxBytes": bytes_value(network_parts[0]) if len(network_parts) == 2 else None,
                       "networkTxBytes": bytes_value(network_parts[1]) if len(network_parts) == 2 else None,
                       "pids": int(metrics["PIDs"]) if metrics.get("PIDs", "").isdigit() else None})
    return {"containers": output, "errors": ["Konteyner kaynak ölçümü alınamadı"] if stats_error else []}


DATABASE_SQL = """
BEGIN READ ONLY;
SET LOCAL statement_timeout = '3000ms';
SELECT json_build_object(
  'database', json_build_object(
    'version', current_setting('server_version'),
    'sizeBytes', pg_database_size(current_database()),
    'connections', (SELECT count(*) FROM pg_stat_activity WHERE datname=current_database() AND pid<>pg_backend_pid()),
    'maxConnections', current_setting('max_connections')::int,
    'activeQueries', (SELECT count(*) FROM pg_stat_activity WHERE datname=current_database() AND state='active' AND pid<>pg_backend_pid()),
    'waitingQueries', (SELECT count(*) FROM pg_stat_activity WHERE datname=current_database() AND wait_event_type='Lock' AND pid<>pg_backend_pid()),
    'longestQuerySeconds', COALESCE((SELECT max(EXTRACT(EPOCH FROM now()-query_start)) FROM pg_stat_activity WHERE datname=current_database() AND state='active' AND pid<>pg_backend_pid()),0),
    'cacheHitPercent', (SELECT CASE WHEN blks_hit+blks_read > 0 THEN round(100.0*blks_hit/(blks_hit+blks_read),2) ELSE NULL END FROM pg_stat_database WHERE datname=current_database()),
    'commits', (SELECT xact_commit FROM pg_stat_database WHERE datname=current_database()),
    'rollbacks', (SELECT xact_rollback FROM pg_stat_database WHERE datname=current_database()),
    'deadlocks', (SELECT deadlocks FROM pg_stat_database WHERE datname=current_database()),
    'statsReset', (SELECT stats_reset FROM pg_stat_database WHERE datname=current_database()),
    'lastMigration', (SELECT max(name) FROM "SequelizeMeta"),
    'tables', COALESCE((SELECT json_agg(t) FROM (SELECT relname AS name, n_live_tup AS rows, pg_total_relation_size(relid) AS bytes FROM pg_stat_user_tables WHERE schemaname='public' ORDER BY pg_total_relation_size(relid) DESC LIMIT 12) t),'[]'::json)
  ),
  'queues', (SELECT json_build_object(
    'expiredPaymentHolds', count(*) FILTER (WHERE status='awaiting_payment' AND "paymentHoldExpiresAt" < now()),
    'pendingRefunds', count(*) FILTER (WHERE "refundStatus"='pending'),
    'staleRefunds', count(*) FILTER (WHERE "refundStatus" IN ('pending','processing') AND COALESCE("refundAttemptedAt", "refundRequestedAt", "updatedAt") < now()-interval '15 minutes'),
    'heldApprovals', count(*) FILTER (WHERE status='picked_up' AND "settlementStatus"='held' AND "paymentStatus"='paid' AND "refundStatus"='none'),
    'awaitingPayment', count(*) FILTER (WHERE status='awaiting_payment')
  ) FROM "Orders" WHERE "deletedAt" IS NULL)
);
COMMIT;
"""


def collect_database():
    start = time.monotonic()
    result = command(["docker", "exec", "-i", CONTAINERS["db"], "sh", "-c",
                      'exec psql -X -qAt -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'], DATABASE_SQL)
    output = json.loads(result.stdout)
    output["database"]["latencyMs"] = round((time.monotonic() - start) * 1000, 2)
    return output


REDIS_NODE = r"""
const Redis = require('ioredis');
const env = process.env;
const configured = name => Boolean(env[name] && !/^(your_|replace|changeme|placeholder)/i.test(env[name]));
const payments = configured('IYZICO_API_KEY') && configured('IYZICO_SECRET_KEY');
const integrations = {
  sentry: configured('SENTRY_DSN'), email: configured('RESEND_API_KEY'),
  google: configured('GOOGLE_CLIENT_ID'), apple: configured('APPLE_CLIENT_ID'), payments,
  paymentMode: !payments ? 'unconfigured' : /sandbox/i.test(env.IYZICO_BASE_URL || 'sandbox') ? 'sandbox' : 'live'
};
let redis;
const finish = value => { if (redis) redis.disconnect(); process.stdout.write(JSON.stringify(value)); };
(async () => {
  try {
    redis = new Redis(env.REDIS_URL || { host: env.REDIS_HOST || 'redis', port: Number(env.REDIS_PORT || 6379), password: env.REDIS_PASSWORD || undefined }, {
      lazyConnect: true, maxRetriesPerRequest: 0, retryStrategy: () => null,
      connectTimeout: 2000, commandTimeout: 2500, enableOfflineQueue: false,
      ...(env.REDIS_URL?.startsWith('rediss://') ? { tls: { rejectUnauthorized: true, ...(env.REDIS_CA_CERT ? { ca: env.REDIS_CA_CERT } : {}) } } : {})
    });
    redis.on('error', () => {});
    const started = performance.now();
    await redis.connect();
    const raw = await redis.info();
    const values = Object.fromEntries(raw.split(/\r?\n/).filter(line => /^[a-zA-Z0-9_]+:/.test(line)).map(line => [line.slice(0,line.indexOf(':')),line.slice(line.indexOf(':')+1)]));
    const n = key => Number(values[key] || 0);
    const hits = n('keyspace_hits'), misses = n('keyspace_misses');
    const dbKeys = Object.entries(values).filter(([key]) => /^db\d+$/.test(key)).reduce((sum,[,value]) => sum + Number(/(?:^|,)keys=(\d+)/.exec(value)?.[1] || 0),0);
    finish({ integrations, redis: {
      version: values.redis_version || 'unknown', uptimeSeconds: n('uptime_in_seconds'),
      usedMemoryBytes: n('used_memory'), maxMemoryBytes: n('maxmemory'), fragmentationRatio: n('mem_fragmentation_ratio'),
      clients: Math.max(0,n('connected_clients')-1), opsPerSecond: n('instantaneous_ops_per_sec'),
      hitRatePercent: hits+misses ? Math.round(hits/(hits+misses)*10000)/100 : null,
      evictedKeys: n('evicted_keys'), rejectedConnections: n('rejected_connections'), keyCount: dbKeys,
      blockedClients: n('blocked_clients'), latencyMs: Math.round((performance.now()-started)*100)/100,
      aofStatus: n('aof_enabled') ? values.aof_last_write_status || 'unknown' : 'disabled',
      rdbStatus: values.rdb_last_bgsave_status || 'unknown',
      lastSaveAt: n('rdb_last_save_time') ? new Date(n('rdb_last_save_time')*1000).toISOString() : null
    }});
  } catch { finish({ integrations, redis: null }); }
})();
"""


def collect_redis():
    output = json.loads(command(["docker", "exec", "-i", "-w", "/app", CONTAINERS["app"], "node", "-"], REDIS_NODE).stdout)
    return output


def collect_alloy():
    value = command(["systemctl", "is-active", "alloy"], check=False).stdout.strip()
    return value if value in ("active", "inactive", "failed", "activating", "deactivating") else "unknown"


def http_probe(url, api=False):
    start = time.monotonic()
    request = urllib.request.Request(url, headers={"User-Agent": "Bitir-Operations/1.0", "Cache-Control": "no-cache"})
    try:
        response = urllib.request.urlopen(request, timeout=5)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        result = {"httpStatus": response.status, "latencyMs": round((time.monotonic() - start) * 1000, 2)}
        if api:
            payload = json.loads(response.read(16384))
            result.update({"status": payload.get("status") if payload.get("status") in ("ok", "unhealthy") else "unknown",
                           "database": payload.get("database") if payload.get("database") in ("connected", "disconnected") else "unknown",
                           "redis": payload.get("redis") if payload.get("redis") in ("connected", "disconnected") else "unknown",
                           "uptimeSeconds": float(payload.get("uptime", 0)),
                           "paymentMode": payload.get("iyzicoMode") if payload.get("iyzicoMode") in ("live", "sandbox", "unconfigured") else "unknown"})
        return result


def collect_tls():
    context = ssl.create_default_context()
    with socket.create_connection(("api.bitirgitsin.com", 443), timeout=5) as raw:
        with context.wrap_socket(raw, server_hostname="api.bitirgitsin.com") as connection:
            expires = ssl.cert_time_to_seconds(connection.getpeercert()["notAfter"])
    return {"expiresAt": utc(expires), "daysRemaining": round((expires - time.time()) / 86400, 1)}


LOG_CATEGORIES = (
    ("Veritabanı", ("sequelize", "database", "postgres", "veritaban")),
    ("Redis / önbellek", ("redis", "caching", "cache")),
    ("Ödeme / iade", ("iyzico", "payment", "refund", "settlement", "reaper", "ödeme", "iade", "approval")),
    ("Kimlik doğrulama", ("auth", "token", "login", "giriş")),
    ("E-posta / bildirim", ("email", "e-posta", "resend", "notification", "bildirim")),
    ("Zamanlanmış işler", ("cron", "job", "tekrarlayan")),
)


def summarize_logs(lines, limit=2000):
    categories, errors, warnings = {}, 0, 0
    for line in lines:
        parts = line.split(" ", 1)
        if len(parts) != 2:
            continue
        try:
            payload = json.loads(parts[1])
        except (ValueError, TypeError):
            continue
        if not isinstance(payload, dict) or payload.get("level") not in ("error", "warn"):
            continue
        errors += payload["level"] == "error"
        warnings += payload["level"] == "warn"
        # Inspect messages in process, but return only fixed category labels.
        message = str(payload.get("message", "")).lower()
        label = next((name for name, patterns in LOG_CATEGORIES if any(pattern in message for pattern in patterns)), "Uygulama")
        timestamp = parts[0] if re.fullmatch(r"\d{4}-\d{2}-\d{2}T[\d:.]+Z", parts[0]) else None
        category = categories.setdefault(label, {"label": label, "count": 0, "lastAt": None})
        category["count"] += 1
        if timestamp and (category["lastAt"] is None or timestamp > category["lastAt"]):
            category["lastAt"] = timestamp
    return {"windowMinutes": 15, "sampledLines": len(lines), "limited": len(lines) >= limit,
            "errors": errors, "warnings": warnings,
            "categories": sorted(categories.values(), key=lambda item: item["count"], reverse=True)}


def collect_logs():
    result = command(["docker", "logs", "--since", "15m", "--tail", "2000", "--timestamps", CONTAINERS["app"]])
    return summarize_logs([line for line in (result.stdout + "\n" + result.stderr).splitlines() if line.strip()])


def collect_backups():
    directory = "/home/deploy/backups"
    files = []
    for name in os.listdir(directory):
        if re.fullmatch(r"bitir_yemek_\d{4}-\d{2}-\d{2}_\d{4}\.sql\.gz", name):
            stat = os.stat(os.path.join(directory, name))
            if stat.st_size > 0:
                files.append(stat)
    latest = max(files, key=lambda item: item.st_mtime) if files else None
    return {"latestAt": utc(latest.st_mtime) if latest else None,
            "ageSeconds": max(0, time.time() - latest.st_mtime) if latest else None,
            "sizeBytes": latest.st_size if latest else None, "count": len(files)}


def collect_release():
    result = command(["git", "-C", REPO, "show", "-s", "--format=%H%n%cI", "HEAD"]).stdout.splitlines()
    if len(result) != 2 or not re.fullmatch(r"[a-f0-9]{40,64}", result[0]):
        raise ValueError("invalid revision")
    dirty = command(["git", "--no-optional-locks", "-C", REPO, "status", "--porcelain", "--untracked-files=no"]).stdout
    return {"checkoutSha": result[0], "checkoutAt": result[1], "checkoutDirty": bool(dirty.strip())}


def collect():
    start = time.monotonic()
    snapshot = {"collectedAt": utc(), "collectionMs": 0, "source": "Canlı VPS", "partialErrors": [],
                "host": None, "containers": [], "database": None, "redis": None,
                "http": {"api": None, "web": None, "tls": None}, "logs": None,
                "backups": None, "release": None, "integrations": None, "queues": None,
                "runtime": None, "runtimeError": None}
    jobs = {"host": ("Sunucu", collect_host), "containers": ("Konteynerler", collect_containers),
            "database": ("PostgreSQL / ödeme kuyrukları", collect_database),
            "redis": ("Redis / entegrasyon yapılandırması", collect_redis), "alloy": ("Alloy", collect_alloy),
            "api": ("API HTTP", lambda: http_probe("https://api.bitirgitsin.com/api/health", api=True)),
            "web": ("Web HTTP", lambda: http_probe("https://bitirgitsin.com")), "tls": ("TLS sertifikası", collect_tls),
            "logs": ("Uygulama logları", collect_logs), "backups": ("Yedekler", collect_backups),
            "release": ("Sunucu kaynak kodu", collect_release)}
    values = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(jobs)) as pool:
        pending = {pool.submit(function): (key, label) for key, (label, function) in jobs.items()}
        for future in concurrent.futures.as_completed(pending):
            key, label = pending[future]
            try:
                values[key] = future.result()
            except Exception:
                snapshot["partialErrors"].append(label + " ölçümü alınamadı")
    for key in ("host", "logs", "backups", "release"):
        snapshot[key] = values.get(key)
    if "containers" in values:
        snapshot["containers"] = values["containers"]["containers"]
        snapshot["partialErrors"].extend(values["containers"]["errors"])
    if "database" in values:
        snapshot.update(values["database"])
    if "redis" in values:
        snapshot.update(values["redis"])
        snapshot["integrations"]["alloy"] = values.get("alloy", "unknown")
        if snapshot["redis"] is None:
            snapshot["partialErrors"].append("Redis ölçümü alınamadı")
    for key in ("api", "web", "tls"):
        snapshot["http"][key] = values.get(key)
    snapshot["partialErrors"].sort()
    snapshot["collectionMs"] = round((time.monotonic() - start) * 1000)
    return snapshot


if __name__ == "__main__":
    print(json.dumps(collect(), ensure_ascii=False, separators=(",", ":"), allow_nan=False))
