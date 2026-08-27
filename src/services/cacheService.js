const Redis = require('ioredis');
const logger = require('./logger');

let redis = null;

const getRedis = () => {
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
          ? { tls: { rejectUnauthorized: false } }
          : {}),
      });

      redis.on('error', (err) => {
        logger.warn('Redis connection error, caching disabled', { error: err.message });
        redis = null;
      });
    } catch (err) {
      logger.warn('Redis initialization failed', { error: err.message });
      redis = null;
    }
  }
  return redis;
};

const get = async (key) => {
  const client = getRedis();
  if (!client) return null;
  try {
    const data = await client.get(key);
    return data ? JSON.parse(data) : null;
  } catch {
    return null;
  }
};

const set = async (key, value, ttl = 300) => {
  const client = getRedis();
  if (!client) return;
  try {
    await client.set(key, JSON.stringify(value), 'EX', ttl);
  } catch {
    // Redis unavailable, skip caching
  }
};

const del = async (key) => {
  const client = getRedis();
  if (!client) return;
  try {
    await client.del(key);
  } catch {
    // Redis unavailable
  }
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

/** Namespace'in geçerli sürümü. Redis yoksa 0 (cache devre dışı gibi davranır). */
const getVersion = async (namespace) => {
  const client = getRedis();
  if (!client) return 0;
  try {
    const v = await client.get(VERSION_PREFIX + namespace);
    return v ? Number(v) : 0;
  } catch {
    return 0;
  }
};

/** Namespace'i geçersiz kılar — O(1). `delPattern`'in yerini alır. */
const invalidateNamespace = async (namespace) => {
  const client = getRedis();
  if (!client) return;
  try {
    await client.incr(VERSION_PREFIX + namespace);
  } catch {
    // Redis unavailable
  }
};

/** `namespace` + parametre objesinden sürümlü cache anahtarı üretir. */
const versionedKey = async (namespace, parts) => {
  const version = await getVersion(namespace);
  return `${namespace}:v${version}:${JSON.stringify(parts)}`;
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
  try {
    const pong = await Promise.race([
      client.ping(),
      new Promise((_, reject) => setTimeout(() => reject(new Error('redis ping timeout')), 2000)),
    ]);
    return pong === 'PONG';
  } catch {
    return false;
  }
};

// Redis bağlantısını düzgün kapatır (graceful shutdown). Bağlantı yoksa no-op.
const quit = async () => {
  if (!redis) return;
  try {
    await redis.quit();
  } catch {
    // zaten kapalı / hata — yut
  } finally {
    redis = null;
  }
};

const storeRefreshToken = async (tokenHash, userId, ttlSeconds = 604800) => {
  await set(`rt:${tokenHash}`, { userId }, ttlSeconds);
};

const revokeRefreshToken = async (tokenHash) => {
  await del(`rt:${tokenHash}`);
};

const isRefreshTokenStored = async (tokenHash) => {
  const val = await get(`rt:${tokenHash}`);
  return val !== null;
};

module.exports = {
  get, set, del, delPattern,
  getVersion, invalidateNamespace, versionedKey,
  isRedisAvailable, ping, quit,
  storeRefreshToken, revokeRefreshToken, isRefreshTokenStored,
};
