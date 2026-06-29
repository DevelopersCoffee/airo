abstract interface class CacheManager {
  Future<void> clearCache();
  Future<int> getCacheSize();
  Future<void> evictExpired(Duration ttl);
}
