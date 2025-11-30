import 'package:meta/meta.dart';

/// Represents a pending sync operation in the outbox.
@immutable
class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastAttemptAt,
    this.lastError,
    this.priority = SyncPriority.normal,
    this.status = SyncOperationStatus.pending,
  });

  /// Unique ID for this operation
  final String id;

  /// Type of entity being synced (e.g., 'transaction', 'budget')
  final String entityType;

  /// ID of the entity being synced
  final String entityId;

  /// Type of operation
  final SyncOperationType operationType;

  /// JSON payload to send to server
  final String payload;

  /// When the operation was created
  final DateTime createdAt;

  /// Number of retry attempts
  final int retryCount;

  /// When the last sync attempt was made
  final DateTime? lastAttemptAt;

  /// Error message from last failed attempt
  final String? lastError;

  /// Priority of this operation
  final SyncPriority priority;

  /// Current status
  final SyncOperationStatus status;

  /// Maximum number of retries before marking as failed
  static const int maxRetries = 5;

  /// Whether this operation can be retried
  bool get canRetry => retryCount < maxRetries;

  /// Calculate backoff delay for retry (exponential: 1s, 2s, 4s, 8s, 16s)
  Duration get retryDelay => Duration(seconds: 1 << retryCount);

  SyncOperation copyWith({
    String? id,
    String? entityType,
    String? entityId,
    SyncOperationType? operationType,
    String? payload,
    DateTime? createdAt,
    int? retryCount,
    DateTime? lastAttemptAt,
    String? lastError,
    SyncPriority? priority,
    SyncOperationStatus? status,
  }) =>
      SyncOperation(
        id: id ?? this.id,
        entityType: entityType ?? this.entityType,
        entityId: entityId ?? this.entityId,
        operationType: operationType ?? this.operationType,
        payload: payload ?? this.payload,
        createdAt: createdAt ?? this.createdAt,
        retryCount: retryCount ?? this.retryCount,
        lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
        lastError: lastError ?? this.lastError,
        priority: priority ?? this.priority,
        status: status ?? this.status,
      );

  @override
  String toString() =>
      'SyncOperation($operationType $entityType:$entityId, status: $status, retries: $retryCount)';
}

/// Type of sync operation
enum SyncOperationType {
  create,
  update,
  delete,
}

/// Priority of sync operation
enum SyncPriority {
  /// Background sync, can wait
  low,

  /// Normal priority
  normal,

  /// User-initiated, should sync ASAP
  high,

  /// Critical financial operation, must sync
  critical,
}

/// Status of sync operation
enum SyncOperationStatus {
  /// Waiting to be synced
  pending,

  /// Currently being synced
  inProgress,

  /// Successfully synced
  completed,

  /// Failed after max retries
  failed,

  /// Cancelled by user/system
  cancelled,
}

