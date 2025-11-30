import 'package:core_domain/core_domain.dart';

import '../connectivity/connectivity_service.dart';

/// Base repository implementation that handles offline-first logic.
///
/// Subclasses should implement the actual data source operations.
abstract class BaseRepository<T extends Entity> implements Repository<T> {
  BaseRepository({
    required this.connectivityService,
  });

  final ConnectivityService connectivityService;

  /// Gets data from remote source
  Future<Result<T>> fetchFromRemote(String id);

  /// Gets data from local cache
  Future<Result<T>> fetchFromLocal(String id);

  /// Saves data to local cache
  Future<Result<T>> saveToLocal(T entity);

  /// Saves data to remote source
  Future<Result<T>> saveToRemote(T entity);

  /// Deletes from local cache
  Future<Result<void>> deleteFromLocal(String id);

  /// Deletes from remote source
  Future<Result<void>> deleteFromRemote(String id);

  @override
  Future<Result<T>> findById(String id) async {
    // Try local first
    final localResult = await fetchFromLocal(id);
    if (localResult.isSuccess) {
      // Refresh from remote in background if online
      _refreshInBackground(id);
      return localResult;
    }

    // If not in local, try remote
    if (await connectivityService.isConnected) {
      final remoteResult = await fetchFromRemote(id);
      if (remoteResult.isSuccess) {
        // Cache locally
        await saveToLocal(remoteResult.value);
      }
      return remoteResult;
    }

    return localResult; // Return local failure if offline
  }

  @override
  Future<Result<T>> save(T entity) async {
    // Always save locally first
    final localResult = await saveToLocal(entity);
    if (localResult.isFailure) {
      return localResult;
    }

    // Try to sync to remote if online
    if (await connectivityService.isConnected) {
      final remoteResult = await saveToRemote(entity);
      if (remoteResult.isFailure) {
        // Queue for later sync (would be handled by sync service)
        // For now, still return success since local save worked
      }
    }

    return localResult;
  }

  @override
  Future<Result<void>> delete(String id) async {
    // Delete locally first
    final localResult = await deleteFromLocal(id);
    if (localResult.isFailure) {
      return localResult;
    }

    // Try to delete from remote if online
    if (await connectivityService.isConnected) {
      await deleteFromRemote(id);
    }

    return localResult;
  }

  void _refreshInBackground(String id) {
    // Fire and forget refresh
    Future.microtask(() async {
      if (await connectivityService.isConnected) {
        final remoteResult = await fetchFromRemote(id);
        if (remoteResult.isSuccess) {
          await saveToLocal(remoteResult.value);
        }
      }
    });
  }
}

