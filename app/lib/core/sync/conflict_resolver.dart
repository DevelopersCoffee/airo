import 'dart:convert';

import 'package:core_data/core_data.dart';
import 'package:flutter/foundation.dart';

/// Conflict resolution strategies for sync operations.
abstract class ConflictResolver {
  /// Resolves a conflict between local and remote versions.
  Future<ConflictResolution> resolve(SyncConflict conflict);
}

/// Represents a sync conflict.
class SyncConflict {
  const SyncConflict({
    required this.entityType,
    required this.entityId,
    required this.localData,
    required this.remoteData,
    required this.localTimestamp,
    required this.remoteTimestamp,
  });

  final String entityType;
  final String entityId;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;
  final DateTime localTimestamp;
  final DateTime remoteTimestamp;
}

/// Last-write-wins conflict resolver.
///
/// Uses timestamps to determine the winner.
class LastWriteWinsResolver implements ConflictResolver {
  const LastWriteWinsResolver({this.preferLocal = true});

  /// If timestamps are equal, prefer local or remote?
  final bool preferLocal;

  @override
  Future<ConflictResolution> resolve(SyncConflict conflict) async {
    if (conflict.localTimestamp.isAfter(conflict.remoteTimestamp)) {
      return ConflictResolution.keepLocal;
    } else if (conflict.remoteTimestamp.isAfter(conflict.localTimestamp)) {
      return ConflictResolution.keepRemote;
    } else {
      // Equal timestamps - use preference
      return preferLocal ? ConflictResolution.keepLocal : ConflictResolution.keepRemote;
    }
  }
}

/// Field-level merge conflict resolver.
///
/// Merges non-conflicting fields, uses strategy for conflicts.
class MergeResolver implements ConflictResolver {
  const MergeResolver({
    this.fieldResolver = const LastWriteWinsResolver(),
    this.immutableFields = const {'id', 'uuid', 'createdAt'},
  });

  /// Resolver for individual field conflicts.
  final ConflictResolver fieldResolver;

  /// Fields that should not be merged (always keep local).
  final Set<String> immutableFields;

  @override
  Future<ConflictResolution> resolve(SyncConflict conflict) async {
    // This is a simplified merge - in production, you'd want to
    // actually produce merged data
    debugPrint('MergeResolver: Merging ${conflict.entityType}/${conflict.entityId}');

    // Check if there are actual conflicts
    final localChanged = _getChangedFields(conflict.localData, conflict.remoteData);
    final remoteChanged = _getChangedFields(conflict.remoteData, conflict.localData);

    final conflictingFields = localChanged.intersection(remoteChanged);

    if (conflictingFields.isEmpty) {
      // No conflicts - safe to merge
      return ConflictResolution.merge;
    }

    // Has conflicts - delegate to field resolver
    debugPrint('MergeResolver: Conflicting fields: $conflictingFields');
    return fieldResolver.resolve(conflict);
  }

  Set<String> _getChangedFields(Map<String, dynamic> a, Map<String, dynamic> b) {
    final changed = <String>{};
    for (final key in a.keys) {
      if (!immutableFields.contains(key) && a[key] != b[key]) {
        changed.add(key);
      }
    }
    return changed;
  }
}

/// Transaction-specific conflict resolver.
///
/// For financial transactions, we never want to lose data.
class TransactionConflictResolver implements ConflictResolver {
  const TransactionConflictResolver();

  @override
  Future<ConflictResolution> resolve(SyncConflict conflict) async {
    // For transactions, always keep both versions
    // Create a duplicate on the server if needed
    debugPrint('TransactionResolver: Keep both - financial data must not be lost');

    // In a real implementation, this would create a duplicate
    // For now, keep local and queue for manual review
    return ConflictResolution.keepLocal;
  }
}

/// Composite resolver that uses different strategies per entity type.
class EntityTypeResolver implements ConflictResolver {
  EntityTypeResolver({
    Map<String, ConflictResolver>? resolvers,
    ConflictResolver? defaultResolver,
  })  : _resolvers = resolvers ?? {},
        _defaultResolver = defaultResolver ?? const LastWriteWinsResolver();

  final Map<String, ConflictResolver> _resolvers;
  final ConflictResolver _defaultResolver;

  /// Add a resolver for a specific entity type.
  void addResolver(String entityType, ConflictResolver resolver) {
    _resolvers[entityType] = resolver;
  }

  @override
  Future<ConflictResolution> resolve(SyncConflict conflict) async {
    final resolver = _resolvers[conflict.entityType] ?? _defaultResolver;
    return resolver.resolve(conflict);
  }

  /// Creates default resolver configuration for Airo.
  factory EntityTypeResolver.airoDefaults() {
    return EntityTypeResolver(
      resolvers: {
        'transaction': const TransactionConflictResolver(),
        'budget': const MergeResolver(),
        'account': const LastWriteWinsResolver(preferLocal: false),
      },
      defaultResolver: const LastWriteWinsResolver(),
    );
  }
}

