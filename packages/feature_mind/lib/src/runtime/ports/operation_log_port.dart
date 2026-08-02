import '../models/log_models.dart';

/// The append-only log.
///
/// [range] rather than a bare list: the Windows console renders a table over
/// 12,000+ ops and must not load them all to show nine.
abstract interface class OperationLogPort {
  Future<int> count();

  /// Ops in descending sequence, newest first, starting at [offset].
  Future<List<MindOp>> range({required int offset, required int limit});

  Future<MindOp?> bySequence(int sequence);

  /// Appends a signed op and returns its sequence number.
  Future<int> append({
    required MindOpKind kind,
    required String title,
    required String contextId,
    String detail,
  });

  /// Re-verifies a signature against the device certificate that claims it.
  ///
  /// Separate from reading the op because the console shows the stored state
  /// and lets a person demand a fresh check on one row.
  Future<SignatureState> verify(int sequence);

  /// Replays the log from [sequence] forward, rebuilding projections.
  ///
  /// Emits fraction complete, so a caller can render progress rather than a
  /// spinner over an unbounded wait.
  Stream<double> replayFrom(int sequence);
}
