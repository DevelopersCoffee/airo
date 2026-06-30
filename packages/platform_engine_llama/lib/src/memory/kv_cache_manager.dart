abstract interface class KvCacheManager {
  int get maxTokens;
  int get currentlyUsedTokens;
  void clear();
}
