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
        // Only negotiate TLS when the URL explicitly asks for it (rediss://).
        // Managed providers (e.g. Railway) use rediss://; a self-hosted Redis
        // container speaks plain redis:// and forcing TLS makes connects hang.
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

const delPattern = async (pattern) => {
  const client = getRedis();
  if (!client) return;
  try {
    const keys = await client.keys(pattern);
    if (keys.length > 0) await client.del(...keys);
  } catch {
    // Redis unavailable
  }
};

const isRedisAvailable = () => getRedis() !== null;

// Bounded health probe: PINGs Redis but never hangs (2s cap). Returns false if
// Redis is unconfigured, unreachable, or slow — used by /api/health.
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

module.exports = { get, set, del, delPattern, isRedisAvailable, ping, storeRefreshToken, revokeRefreshToken, isRefreshTokenStored };
