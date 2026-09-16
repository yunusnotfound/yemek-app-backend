/// In-memory TTL cache for API responses.
///
/// Usage:
/// ```dart
/// final cache = CacheService();
///
/// // Store a value with a 5-minute TTL (default)
/// cache.set('packages:page1', packagesData);
///
/// // Retrieve — returns null if missing or expired
/// final cached = cache.get<Map<String, dynamic>>('packages:page1');
///
/// // Invalidate a single key
/// cache.invalidate('packages:page1');
///
/// // Invalidate all keys that begin with 'packages:'
/// cache.invalidatePattern('packages:');
/// ```
class CacheService {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------
  static final CacheService _instance = CacheService._internal();

  factory CacheService() => _instance;

  CacheService._internal();

  // ---------------------------------------------------------------------------
  // Internal storage
  // ---------------------------------------------------------------------------
  final Map<String, _CacheEntry> _cache = {};
  static const int maxEntries = 100;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns the cached value for [key], or `null` if the entry is absent or
  /// has expired.  Expired entries are eagerly evicted on access.
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (!DateTime.now().isBefore(entry.expiry)) {
      _cache.remove(key);
      return null;
    }
    // Map insertion order doubles as a least-recently-used queue.
    _cache.remove(key);
    _cache[key] = entry;
    return entry.data as T?;
  }

  /// Stores [data] under [key] with a time-to-live of [ttl] (default 5 min).
  void set(
    String key,
    dynamic data, {
    Duration ttl = const Duration(minutes: 5),
  }) {
    _evictExpired();
    _cache.remove(key);
    if (ttl <= Duration.zero) return;
    if (_cache.length >= maxEntries) _cache.remove(_cache.keys.first);
    _cache[key] = _CacheEntry(data: data, expiry: DateTime.now().add(ttl));
  }

  /// Returns `true` if [key] exists in the cache and has not yet expired.
  bool has(String key) {
    final entry = _cache[key];
    if (entry == null) return false;
    if (!DateTime.now().isBefore(entry.expiry)) {
      _cache.remove(key);
      return false;
    }
    return true;
  }

  /// Removes the entry for [key], if present.
  void invalidate(String key) => _cache.remove(key);

  /// Removes all entries whose keys start with [pattern].
  ///
  /// Example: `invalidatePattern('packages:')` clears all package list pages.
  void invalidatePattern(String pattern) {
    _cache.removeWhere((key, _) => key.startsWith(pattern));
  }

  /// Removes all cached entries.
  void clear() => _cache.clear();

  /// Returns the current number of live (non-expired) entries.
  int get length {
    _evictExpired();
    return _cache.length;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Removes all expired entries in a single pass.  Call periodically or
  /// before any size/stats check to keep memory usage in check.
  void _evictExpired() {
    final now = DateTime.now();
    _cache.removeWhere((_, entry) => !now.isBefore(entry.expiry));
  }
}

// -----------------------------------------------------------------------------
// Internal value type
// -----------------------------------------------------------------------------

class _CacheEntry {
  final dynamic data;
  final DateTime expiry;

  const _CacheEntry({required this.data, required this.expiry});
}
