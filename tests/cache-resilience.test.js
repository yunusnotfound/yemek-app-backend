jest.mock('../src/services/logger', () => ({ warn: jest.fn() }));
jest.mock('ioredis', () => {
  const instances = [];
  const data = new Map();
  return class Redis {
    static instances = instances;
    static data = data;
    constructor(config, options) {
      this.options = options;
      this.status = 'ready';
      this.on = jest.fn();
      this.get = jest.fn(async (key) => data.get(key) ?? null);
      this.set = jest.fn(async (key, value) => { data.set(key, value); return 'OK'; });
      this.del = jest.fn(async (key) => Number(data.delete(key)));
      this.incr = jest.fn(async (key) => {
        const value = Number(data.get(key) || 0) + 1;
        data.set(key, String(value));
        return value;
      });
      this.getdel = jest.fn(async (key) => { const value = data.get(key); data.delete(key); return value; });
      this.eval = jest.fn().mockResolvedValue(1);
      this.quit = jest.fn(async () => { this.status = 'end'; });
      this.disconnect = jest.fn(() => { this.status = 'end'; });
      instances.push(this);
    }
  };
});

let cache;
let Redis;
beforeEach(() => {
  jest.resetModules();
  cache = require('../src/services/cacheService');
  Redis = require('ioredis');
});
afterEach(async () => { await cache.quit(); jest.restoreAllMocks(); });

test('optional caching never queues commands while disconnected', async () => {
  await cache.get('warmup');
  const client = Redis.instances[0];
  client.status = 'reconnecting';
  client.get.mockClear();
  expect(await cache.versionedKey('packages:list', {})).toBeNull();
  expect(await cache.get(null)).toBeNull();
  await cache.set(null, { stale: true });
  expect(client.get).not.toHaveBeenCalled();
  expect(client.set).not.toHaveBeenCalled();
  expect(client.options).toMatchObject({ enableOfflineQueue: false, maxRetriesPerRequest: 0, commandTimeout: 100, connectTimeout: 200 });
});

test('a failed version lookup cannot read or populate the old v0 cache', async () => {
  await cache.get('warmup');
  const client = Redis.instances[0];
  client.get.mockRejectedValue(new Error('socket stalled'));
  const key = await cache.versionedKey('packages:list', {});
  expect(key).toBeNull();
  expect(await cache.get(key)).toBeNull();
  await cache.set(key, { stale: true });
  expect(client.set).not.toHaveBeenCalled();
  expect(client.disconnect).toHaveBeenCalledTimes(1);
  await cache.get('during-cooldown');
  expect(Redis.instances).toHaveLength(1);
});

test('missed namespace invalidations replay before cache resumes after an outage', async () => {
  const oldKey = await cache.versionedKey('packages:list', {});
  await cache.set(oldKey, { remainingQuantity: 10 });
  const client = Redis.instances[0];
  client.status = 'reconnecting';
  await cache.invalidateNamespace('packages:list');
  expect(client.incr).not.toHaveBeenCalled();
  expect(await cache.getVersion('packages:list')).toBeNull();
  client.status = 'ready';
  const newKey = await cache.versionedKey('packages:list', {});
  expect(newKey).not.toBe(oldKey);
  expect(await cache.get(newKey)).toBeNull();
  expect(client.incr).toHaveBeenCalledWith('cachever:packages:list');
});

test('a same-tick read cannot let invalidation finish without advancing the namespace', async () => {
  const oldKey = await cache.versionedKey('packages:list', {});
  await cache.set(oldKey, { remainingQuantity: 10 });
  // Construct these synchronously: an empty/settled shared drain must not hide
  // the mutation from the read started immediately after it.
  const beforeMutation = cache.versionedKey('packages:list', {});
  const invalidation = cache.invalidateNamespace('packages:list');
  const afterMutation = cache.versionedKey('packages:list', {});
  const [, , newKey] = await Promise.all([beforeMutation, invalidation, afterMutation]);
  expect(Redis.instances[0].incr).toHaveBeenCalledWith('cachever:packages:list');
  expect(newKey).not.toBe(oldKey);
  expect(await cache.get(newKey)).toBeNull();
});

test('a same-tick read cannot bypass a pending key deletion', async () => {
  await cache.set('unversioned-list', { stale: true });
  const beforeMutation = cache.get('unrelated-key');
  const deletion = cache.del('unversioned-list');
  const afterMutation = cache.get('unversioned-list');
  const [, , cached] = await Promise.all([beforeMutation, deletion, afterMutation]);
  expect(Redis.instances[0].del).toHaveBeenCalledWith('unversioned-list');
  expect(cached).toBeNull();
});

test('invalidation arriving during a pending INCR is not dropped', async () => {
  await cache.get('warmup');
  const client = Redis.instances[0];
  let release;
  client.incr.mockImplementationOnce(() => new Promise((resolve) => { release = resolve; }));
  const first = cache.invalidateNamespace('packages:list');
  const second = cache.invalidateNamespace('packages:list');
  release(1);
  await Promise.all([first, second]);
  expect(client.incr).toHaveBeenCalledTimes(2);
});

test('an invalidation arriving between drain completion and promise cleanup starts a new drain', async () => {
  await cache.get('warmup');
  const client = Redis.instances[0];
  const increment = client.incr.getMockImplementation();
  let secondInvalidation;
  let readAfterSecondMutation;
  client.incr.mockImplementationOnce((key) => {
    const result = increment(key);
    // The first microtask runs before the drain continuation; the nested one
    // then runs after that continuation and before its finally callback.
    Promise.resolve().then(() => queueMicrotask(() => {
      secondInvalidation = cache.invalidateNamespace('packages:list');
      readAfterSecondMutation = cache.versionedKey('packages:list', {});
    }));
    return result;
  });
  await cache.invalidateNamespace('packages:list');
  await secondInvalidation;
  expect(await readAfterSecondMutation).toContain(':v2:');
  expect(client.incr).toHaveBeenCalledTimes(2);
});

test('an unsuccessful invalidation is retained across connection replacement', async () => {
  await cache.get('warmup');
  Redis.instances[0].incr.mockRejectedValue(new Error('down'));
  await cache.invalidateNamespace('packages:list');
  const now = Date.now();
  jest.spyOn(Date, 'now').mockReturnValue(now + 2000);
  const key = await cache.versionedKey('packages:list', {});
  expect(key).toContain(':v1:');
  expect(Redis.instances).toHaveLength(2);
});

test('refresh tokens and identity limits use a separate strict connection and propagate failures', async () => {
  await cache.get('warmup');
  Redis.instances[0].status = 'reconnecting';
  await cache.storeRefreshToken('token', 'user');
  const strict = Redis.instances[1];
  expect(strict.options.enableOfflineQueue).not.toBe(false);
  expect(await cache.consumeRefreshToken('token')).toEqual({ userId: 'user' });
  expect(await cache.consumeRefreshToken('token')).toBeNull();
  strict.set.mockRejectedValue(new Error('session store unavailable'));
  strict.get.mockRejectedValue(new Error('session store unavailable'));
  strict.eval.mockRejectedValue(new Error('session store unavailable'));
  await expect(cache.storeRefreshToken('another', 'user')).rejects.toThrow();
  await expect(cache.isRefreshTokenStored('another')).rejects.toThrow();
  await expect(cache.limitAuthIdentity('user@test.local', 'login')).rejects.toThrow();
});
