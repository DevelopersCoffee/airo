/// In-memory HTTP response cache for research fetches.
///
/// Keys are canonical HTTPS URLs. Entries expire after [defaultTtl].
class ResearchHttpCache {
  ResearchHttpCache({
    this.maxEntries = 128,
    this.defaultTtl = const Duration(hours: 24),
  });

  final int maxEntries;
  final Duration defaultTtl;
  final Map<String, _ResearchHttpCacheEntry> _entries = {};

  String? read(String canonicalUrl, DateTime now) {
    final entry = _entries[canonicalUrl];
    if (entry == null) {
      return null;
    }
    if (now.isAfter(entry.expiresAt)) {
      _entries.remove(canonicalUrl);
      return null;
    }
    return entry.body;
  }

  void write(String canonicalUrl, String body, DateTime now) {
    if (_entries.length >= maxEntries && !_entries.containsKey(canonicalUrl)) {
      final oldest = _entries.entries.reduce(
        (left, right) =>
            left.value.storedAt.isBefore(right.value.storedAt) ? left : right,
      );
      _entries.remove(oldest.key);
    }
    _entries[canonicalUrl] = _ResearchHttpCacheEntry(
      body: body,
      storedAt: now,
      expiresAt: now.add(defaultTtl),
    );
  }

  void clear() => _entries.clear();
}

class _ResearchHttpCacheEntry {
  const _ResearchHttpCacheEntry({
    required this.body,
    required this.storedAt,
    required this.expiresAt,
  });

  final String body;
  final DateTime storedAt;
  final DateTime expiresAt;
}

/// Process-wide cache shared across research jobs in one isolate.
final researchHttpCache = ResearchHttpCache();
