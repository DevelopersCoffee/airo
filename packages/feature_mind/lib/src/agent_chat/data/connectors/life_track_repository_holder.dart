import 'package:core_domain/core_domain.dart';

/// Delegates LifeTrack repository calls after secure stack initialization.
class DelegatingLifeTrackRepository implements LifeTrackRepository {
  DelegatingLifeTrackRepository(this._delegate);

  LifeTrackRepository _delegate;

  void adopt(LifeTrackRepository repository) {
    _delegate = repository;
  }

  @override
  Future<Result<LifeTrack>> createTrack(LifeTrack track) =>
      _delegate.createTrack(track);

  @override
  Future<Result<void>> deleteTrack(String id) => _delegate.deleteTrack(id);

  @override
  Future<Result<LifeTrack>> getTrack(String id) => _delegate.getTrack(id);

  @override
  Future<Result<List<LifeTrack>>> listTracks({TrackStatus? status}) =>
      _delegate.listTracks(status: status);

  @override
  Future<Result<void>> saveInputValue(
    String requirementId,
    String value,
  ) => _delegate.saveInputValue(requirementId, value);

  @override
  Future<Result<void>> updateActionItem(ActionItem item) =>
      _delegate.updateActionItem(item);

  @override
  Future<Result<void>> updateItemStatus(
    String itemId,
    ItemStatus status,
  ) => _delegate.updateItemStatus(itemId, status);

  @override
  Future<Result<void>> updateMilestone(Milestone milestone) =>
      _delegate.updateMilestone(milestone);

  @override
  Future<Result<void>> updateTrack(LifeTrack track) =>
      _delegate.updateTrack(track);

  @override
  Stream<List<LifeTrack>> watchTracks({TrackStatus? status}) =>
      _delegate.watchTracks(status: status);
}

/// Idempotency port that activates when the encrypted stack is ready.
class DelegatingIdempotentEffectPort implements IdempotentEffectPort {
  IdempotentEffectPort? _delegate;

  void adopt(IdempotentEffectPort port) => _delegate = port;

  @override
  Future<Result<IdempotentEffectRecord?>> findByKey(String idempotencyKey) {
    final delegate = _delegate;
    if (delegate == null) {
      return Future.value(const Ok(null));
    }
    return delegate.findByKey(idempotencyKey);
  }

  @override
  Future<Result<IdempotentEffectRecord>> beginEffect({
    required String idempotencyKey,
    required String confirmationHash,
    required String resourceId,
  }) {
    final delegate = _delegate;
    if (delegate == null) {
      return Future.value(
        Err(
          SecureDestinationUnavailableError(
            'LifeTrack idempotency requires encrypted storage',
          ),
          StackTrace.current,
        ),
      );
    }
    return delegate.beginEffect(
      idempotencyKey: idempotencyKey,
      confirmationHash: confirmationHash,
      resourceId: resourceId,
    );
  }

  @override
  Future<Result<void>> commitEffect({
    required String idempotencyKey,
    required String destinationReceipt,
  }) {
    final delegate = _delegate;
    if (delegate == null) {
      return Future.value(
        Err(
          SecureDestinationUnavailableError(
            'LifeTrack idempotency requires encrypted storage',
          ),
          StackTrace.current,
        ),
      );
    }
    return delegate.commitEffect(
      idempotencyKey: idempotencyKey,
      destinationReceipt: destinationReceipt,
    );
  }

  @override
  Future<Result<void>> markFailed(String idempotencyKey) {
    final delegate = _delegate;
    if (delegate == null) {
      return Future.value(const Ok(null));
    }
    return delegate.markFailed(idempotencyKey);
  }
}
