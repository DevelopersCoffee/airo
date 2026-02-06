import '../entities/entity.dart';
import '../result/result.dart';

/// Base interface for all repositories.
///
/// Repositories provide access to domain entities and abstract away
/// the data source implementation details.
abstract class Repository<T extends Entity> {
  /// Finds an entity by its unique identifier.
  Future<Result<T>> findById(String id);

  /// Returns all entities of this type.
  Future<Result<List<T>>> findAll();

  /// Saves (creates or updates) an entity.
  Future<Result<T>> save(T entity);

  /// Deletes an entity by its unique identifier.
  Future<Result<void>> delete(String id);
}

/// Repository that supports pagination
abstract class PaginatedRepository<T extends Entity> extends Repository<T> {
  /// Returns a page of entities.
  ///
  /// [page] is 0-indexed.
  /// [pageSize] is the number of items per page.
  Future<Result<Page<T>>> findPage({required int page, required int pageSize});
}

/// Represents a page of results from a paginated query.
class Page<T> {
  const Page({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalItems,
  });

  /// Items in this page
  final List<T> items;

  /// Current page number (0-indexed)
  final int page;

  /// Number of items per page
  final int pageSize;

  /// Total number of items across all pages
  final int totalItems;

  /// Total number of pages
  int get totalPages => (totalItems / pageSize).ceil();

  /// Whether there is a next page
  bool get hasNext => page < totalPages - 1;

  /// Whether there is a previous page
  bool get hasPrevious => page > 0;

  /// Whether this page is empty
  bool get isEmpty => items.isEmpty;

  /// Whether this page has items
  bool get isNotEmpty => items.isNotEmpty;
}
