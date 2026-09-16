const Redis = require('ioredis');
const logger = require('./logger');

let redis = null;

const getRedis = () => {
  // Replace only a fully closed client, allowing recovery after an outage
  // without spawning connections on every transient error event.
  if (redis?.status === 'end') redis = null;
  if (!redis) {
    try {
      // Railway provides REDIS_URL; use it if available
      const redisUrl = process.env.REDIS_URL;
      const redisConfig = redisUrl
        ? redisUrl
        : {
            host: process.env.REDIS_HOST || 'localhost',
            port: parseInt(process.env.REDIS_PORT) || 6379,
            password: process.env.REDIS_PASSWORD || undefined,
          };

      redis = new Redis(redisConfig, {
        retryStrategy: (times) => {
          if (times > 3) return null;
          return Math.min(times * 200, 2000);
        },
        lazyConnect: true,
        maxRetriesPerRequest: 3,
        // TLS yalnızca rediss:// için; düz redis://'e TLS dayatmak bağlantıyı askıda bırakır.
        ...(process.env.REDIS_URL && process.env.REDIS_URL.startsWith('rediss://')
          ? { tls: { rejectUnauthorized: true, ...(process.env.REDIS_CA_CERT ? { ca: process.env.REDIS_CA_CERT } : {}) } }
          : {}),
      });

      redis.on('error', (err) => {
        logger.warn('Redis connection error, caching disabled', { error: err.message });
        // Keep this client: creating clients on every error leaks connections.
      });
    } catch (err) {
      logger.warn('Redis initialization failed', { error: err.message });
      redis = null;
    }
  }
  return redis;
};

// Optional list caching uses its own connection. Session creation, refresh
// rotation and identity limits below keep their strict, fail-closed client.
const CACHE_COMMAND_TIMEOUT_MS = 100;
const CACHE_RETRY_DELAY_MS = 1000;
let cacheRedis = null;
let retryCacheAfter = 0;
let flushingInvalidations = null;
const pendingNamespaces = new Set();
const pendingDeletes = new Set();

const getCacheRedis = () => {
  if (Date.now() < retryCacheAfter) return null;
  if (cacheRedis?.status === 'end') cacheRedis = null;
  if (!cacheRedis) {
    const config = process.env.REDIS_URL || {
      host: process.env.REDIS_HOST || 'localhost',
      port: parseInt(process.env.REDIS_PORT) || 6379,
      password: process.env.REDIS_PASSWORD || undefined,
    };
    cacheRedis = new Redis(config, {
      // Never queue optional cache work while Redis connects or reconnects.
      enableOfflineQueue: false,
      maxRetriesPerRequest: 0,
      connectTimeout: 200,
      commandTimeout: CACHE_COMMAND_TIMEOUT_MS,
      retryStrategy: () => CACHE_RETRY_DELAY_MS,
      ...(process.env.REDIS_URL?.startsWith('rediss://')
        ? { tls: { rejectUnauthorized: true, ...(process.env.REDIS_CA_CERT ? { ca: process.env.REDIS_CA_CERT } : {}) } }
        : {}),
    });
    cacheRedis.on('error', () => {
      // Automatic reconnect is bounded and happens away from the request path.
      retryCacheAfter = Date.now() + CACHE_RETRY_DELAY_MS;
    });
  }
  return cacheRedis.status === 'ready' ? cacheRedis : null;
};

// An invalidation missed during an outage must be replayed before cache reads
// resume, otherwise old stock/moderation results can become visible again.
const flushInvalidations = async (client) => {
  // Recheck after every joined drain. A mutation can arrive after its loop has
  // finished but before the shared promise's finally callback clears it.
  // Also wait for a replacement drain that another waiter has already started.
  while (flushingInvalidations || pendingNamespaces.size || pendingDeletes.size) {
    if (!flushingInvalidations) {
      flushingInvalidations = (async () => {
        while (pendingNamespaces.size || pendingDeletes.size) {
          for (const namespace of [...pendingNamespaces]) {
            // Remove BEFORE awaiting so a concurrent new invalidation is retained.
            pendingNamespaces.delete(namespace);
            try {
              await client.incr(VERSION_PREFIX + namespace);
            } catch (error) {
              pendingNamespaces.add(namespace);
              throw error;
            }
          }
          for (const key of [...pendingDeletes]) {
            pendingDeletes.delete(key);
            try {
              await client.del(key);
            } catch (error) {
              pendingDeletes.add(key);
              throw error;
            }
          }
        }
      })().finally(() => { flushingInvalidations = null; });
    }
    await flushingInvalidations;
  }
};

const optionalCache = async (operation, fallback = null) => {
  let client;
  try {
    client = getCacheRedis();
    if (!client) return fallback;
    await flushInvalidations(client);
    return await operation(client);
  } catch {
    retryCacheAfter = Date.now() + CACHE_RETRY_DELAY_MS;
    // Abandon a stalled socket/queued command so late writes cannot linger.
    client?.disconnect();
    return fallback;
  }
};

const isSessionKey = (key) => /^(rt|authlimit):/.test(key);

const get = async (key) => {
  if (!key) return null;
  // Keep legacy direct session-key callers fail-closed too.
  if (isSessionKey(key)) {
    const data = await getRedis().get(key);
    return data ? JSON.parse(data) : null;
  }
  return optionalCache(async (client) => {
    const data = await client.get(key);
    return data ? JSON.parse(data) : null;
  });
};

const set = async (key, value, ttl = 300) => {
  if (!key) return;
  if (isSessionKey(key)) {
    await getRedis().set(key, JSON.stringify(value), 'EX', ttl);
    return;
  }
  await optionalCache((client) => client.set(key, JSON.stringify(value), 'EX', ttl));
};

const del = async (key) => {
  if (!key) return;
  if (isSessionKey(key)) {
    await getRedis().del(key);
    return;
  }
  pendingDeletes.add(key);
  await optionalCache(async () => {});
};

// ---------------------------------------------------------------------------
// Namespace sürümleme ile O(1) geçersiz kılma
// ---------------------------------------------------------------------------
//
// Liste cache'leri (paket/işletme listeleri) anahtarına konum, sayfa, kategori
// gibi çok sayıda parametre gömüyor; bu yüzden namespace başına binlerce anahtar
// oluşabiliyor. Bunları `KEYS pattern` ile silmek Redis'in TEK thread'ini
// keyspace boyunca bloke eder ve KEYS eşleşenleri değil TÜM anahtarları gezer —
// aynı Redis'te refresh token'lar da durduğu için o an giriş yapan herkes bekler.
// Sipariş oluşturma gibi sıcak yollardan çağrıldığı düşünülürse kabul edilemez.
//
// Bunun yerine namespace'in bir sürüm sayacı tutulur ve anahtara gömülür:
//   packages:list:v7:{"city":"istanbul",...}
// Geçersiz kılmak tek bir INCR (O(1)); eski sürümdeki anahtarlar okunmaz olur ve
// kendi TTL'leriyle sessizce ölür. Tarama yok, bloke yok.

const VERSION_PREFIX = 'cachever:';

/** Missing counter is v0; unavailable Redis is null and MUST disable caching. */
const getVersion = async (namespace) => optionalCache(async (client) => {
  const value = await client.get(VERSION_PREFIX + namespace);
  const version = value ? Number(value) : 0;
  return Number.isSafeInteger(version) && version >= 0 ? version : null;
});

/** Namespace'i geçersiz kılar — O(1). Kesintide işlem yeniden denenmek üzere kalır. */
const invalidateNamespace = async (namespace) => {
  pendingNamespaces.add(namespace);
  await optionalCache(async () => {});
};

/** A null key prevents reading/writing stale v0 entries after a version failure. */
const versionedKey = async (namespace, parts) => {
  const version = await getVersion(namespace);
  return version === null ? null : `${namespace}:v${version}:${JSON.stringify(parts)}`;
};

/**
 * Desen bazlı silme. Artık `KEYS` değil `SCAN` kullanır (cursor'lı, bloke etmez).
 * Sıcak yollarda YİNE DE kullanmayın — tercih `invalidateNamespace`'tir; bu yalnız
 * tek seferlik/bakım amaçlı temizlik için bırakıldı.
 */
const delPattern = async (pattern) => {
  const client = getRedis();
  if (!client) return;
  try {
    let cursor = '0';
    do {
      const [next, keys] = await client.scan(cursor, 'MATCH', pattern, 'COUNT', 200);
      cursor = next;
      if (keys.length > 0) await client.del(...keys);
    } while (cursor !== '0');
  } catch {
    // Redis unavailable
  }
};

const isRedisAvailable = () => getRedis() !== null;

// Redis'i PING'ler ama asla takılmaz (2sn sınır); /api/health kullanır.
const ping = async () => {
  const client = getRedis();
  if (!client) return false;
  let timer;
  try {
    const pong = await Promise.race([
      client.ping(),
      new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error('redis ping timeout')), 2000);
      }),
    ]);
    return pong === 'PONG';
  } catch {
    return false;
  } finally {
    clearTimeout(timer);
  }
};

// Close both connections; disconnected clients need no queued QUIT command.
const quit = async () => {
  cacheRedis?.disconnect();
  cacheRedis = null;
  retryCacheAfter = 0;
  if (!redis) return;
  try {
    if (redis.status === 'ready') await redis.quit();
    else redis.disconnect();
  } catch {
    redis.disconnect();
  } finally {
    redis = null;
  }
};

const storeRefreshToken = async (tokenHash, userId, ttlSeconds = 604800) => {
  const client = getRedis();
  if (!client) throw new Error('Oturum deposuna ulaşılamıyor');
  await client.set(`rt:${tokenHash}`, JSON.stringify({ userId }), 'EX', ttlSeconds);
};

const revokeRefreshToken = async (tokenHash) => {
  const client = getRedis();
  if (!client) throw new Error('Oturum deposuna ulaşılamıyor');
  await client.del(`rt:${tokenHash}`);
};

// GET + DEL must be one operation: concurrent requests may not reuse a token.
const consumeRefreshToken = async (tokenHash) => {
  const client = getRedis();
  if (!client) throw new Error('Oturum deposuna ulaşılamıyor');
  const value = await client.getdel(`rt:${tokenHash}`);
  return value ? JSON.parse(value) : null;
};

const limitAuthIdentity = async (identity, action, limit = 5, seconds = 900) => {
  const client = getRedis();
  if (!client) throw new Error('Oturum deposuna ulaşılamıyor');
  const key = `authlimit:${action}:${require('crypto').createHash('sha256').update(identity).digest('hex')}`;
  const count = await client.eval(
    "local n = redis.call('INCR', KEYS[1]); if n == 1 then redis.call('EXPIRE', KEYS[1], ARGV[1]) end; return n",
    1, key, seconds
  );
  return Number(count) <= limit;
};

const isRefreshTokenStored = async (tokenHash) => {
  const val = await get(`rt:${tokenHash}`);
  return val !== null;
};

module.exports = {
  get, set, del, delPattern,
  getVersion, invalidateNamespace, versionedKey,
  isRedisAvailable, ping, quit,
  storeRefreshToken, revokeRefreshToken, isRefreshTokenStored, consumeRefreshToken, limitAuthIdentity,
};
