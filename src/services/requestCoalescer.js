// Share concurrent public reads for an identical cache key within this process.
// No settled value is retained: Redis owns TTLs and namespace invalidation.
const pending = new Map();
const MAX_PENDING_KEYS = 256;

module.exports = async function coalesce(key, load) {
  if (key == null) return load();
  if (pending.has(key)) return pending.get(key);
  if (pending.size >= MAX_PENDING_KEYS) return load();
  const result = Promise.resolve().then(load);
  pending.set(key, result);
  try {
    return await result;
  } finally {
    if (pending.get(key) === result) pending.delete(key);
  }
};
