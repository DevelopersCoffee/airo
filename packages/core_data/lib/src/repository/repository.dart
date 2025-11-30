import 'package:core_domain/core_domain.dart';

/// Base repository interface for fetching data.
abstract interface class Repository<TQuery, TOut> {
  /// Fetch data based on query
  Future<Result<TOut>> fetch(TQuery query);
}

/// Base cache repository interface.
abstract interface class CacheRepository<TId, T> {
  /// Get item from cache
  Future<T?> get(TId id);

  /// Put item into cache
  Future<void> put(TId id, T data);

  /// Get all items from cache
  Future<List<T>> getAll();

  /// Clear specific item from cache
  Future<void> delete(TId id);

  /// Clear all items from cache
  Future<void> clear();

  /// Check if item exists in cache
  Future<bool> exists(TId id);
}

/// Base paginated repository interface.
abstract interface class PaginatedRepository<TQuery, TOut> {
  /// Fetch paginated data
  Future<Result<(List<TOut>, String?)>> fetch(TQuery query, {String? cursor});
}

/// Base stream repository interface.
abstract interface class StreamRepository<TQuery, TOut> {
  /// Stream data based on query
  Stream<Result<TOut>> stream(TQuery query);
}

/// In-memory cache implementation of CacheRepository.
class InMemoryCacheRepository<TId, T> implements CacheRepository<TId, T> {
  final Map<TId, T> _cache = {};

  @override
  Future<T?> get(TId id) async => _cache[id];

  @override
  Future<void> put(TId id, T data) async {
    _cache[id] = data;
  }

  @override
  Future<List<T>> getAll() async => _cache.values.toList();

  @override
  Future<void> delete(TId id) async {
    _cache.remove(id);
  }

  @override
  Future<void> clear() async {
    _cache.clear();
  }

  @override
  Future<bool> exists(TId id) async => _cache.containsKey(id);
}

