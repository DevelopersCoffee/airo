/// Sync status for offline-first data.
enum SyncStatus {
  /// Data is synced with remote.
  synced,

  /// Data is pending sync (created/updated locally).
  pending,

  /// Data is being synced.
  syncing,

  /// Sync failed, will retry.
  failed,

  /// Data has conflicts that need resolution.
  conflict,
}

/// Metadata for syncable entities.
class SyncMetadata {
  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final DateTime? lastModifiedAt;
  final int retryCount;
  final String? errorMessage;
  final String? remoteId;
  final int version;

  const SyncMetadata({
    this.status = SyncStatus.pending,
    this.lastSyncedAt,
    this.lastModifiedAt,
    this.retryCount = 0,
    this.errorMessage,
    this.remoteId,
    this.version = 1,
  });

  /// Check if needs sync.
  bool get needsSync => status == SyncStatus.pending || status == SyncStatus.failed;

  /// Check if has error.
  bool get hasError => status == SyncStatus.failed && errorMessage != null;

  /// Create a copy with updated values.
  SyncMetadata copyWith({
    SyncStatus? status,
    DateTime? lastSyncedAt,
    DateTime? lastModifiedAt,
    int? retryCount,
    String? errorMessage,
    String? remoteId,
    int? version,
    bool clearError = false,
  }) {
    return SyncMetadata(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      remoteId: remoteId ?? this.remoteId,
      version: version ?? this.version,
    );
  }

  /// Mark as syncing.
  SyncMetadata markSyncing() {
    return copyWith(status: SyncStatus.syncing, clearError: true);
  }

  /// Mark as synced.
  SyncMetadata markSynced({String? remoteId}) {
    return copyWith(
      status: SyncStatus.synced,
      lastSyncedAt: DateTime.now(),
      remoteId: remoteId ?? this.remoteId,
      retryCount: 0,
      clearError: true,
    );
  }

  /// Mark as failed.
  SyncMetadata markFailed(String error) {
    return copyWith(
      status: SyncStatus.failed,
      errorMessage: error,
      retryCount: retryCount + 1,
    );
  }

  /// Mark as pending (modified locally).
  SyncMetadata markPending() {
    return copyWith(
      status: SyncStatus.pending,
      lastModifiedAt: DateTime.now(),
      version: version + 1,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() {
    return {
      'status': status.name,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'lastModifiedAt': lastModifiedAt?.toIso8601String(),
      'retryCount': retryCount,
      'errorMessage': errorMessage,
      'remoteId': remoteId,
      'version': version,
    };
  }

  /// Create from JSON.
  factory SyncMetadata.fromJson(Map<String, dynamic> json) {
    return SyncMetadata(
      status: SyncStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SyncStatus.pending,
      ),
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.parse(json['lastSyncedAt'] as String)
          : null,
      lastModifiedAt: json['lastModifiedAt'] != null
          ? DateTime.parse(json['lastModifiedAt'] as String)
          : null,
      retryCount: json['retryCount'] as int? ?? 0,
      errorMessage: json['errorMessage'] as String?,
      remoteId: json['remoteId'] as String?,
      version: json['version'] as int? ?? 1,
    );
  }
}

