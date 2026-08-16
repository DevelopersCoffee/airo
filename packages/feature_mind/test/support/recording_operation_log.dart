import 'package:feature_mind/src/runtime/models/log_models.dart';
import 'package:feature_mind/src/runtime/ports/operation_log_port.dart';

/// In-memory [OperationLogPort] for tests that assert on appended ops.
class RecordingOperationLog implements OperationLogPort {
  final List<MindOp> appended = [];

  @override
  Future<int> append({
    required MindOpKind kind,
    required String title,
    required String contextId,
    String detail = '',
  }) async {
    final sequence = appended.length + 1;
    appended.add(
      MindOp(
        sequence: sequence,
        kind: kind,
        title: title,
        contextId: contextId,
        deviceName: 'Test device',
        signature: SignatureState.verified,
        recordedAtMs: 1000 + sequence,
        detail: detail,
      ),
    );
    return sequence;
  }

  @override
  Future<int> count() async => appended.length;

  @override
  Future<List<MindOp>> range({required int offset, required int limit}) async =>
      appended.reversed.skip(offset).take(limit).toList();

  @override
  Future<MindOp?> bySequence(int sequence) async =>
      appended.where((op) => op.sequence == sequence).firstOrNull;

  @override
  Future<SignatureState> verify(int sequence) async =>
      (await bySequence(sequence))?.signature ?? SignatureState.unsigned;

  @override
  Stream<double> replayFrom(int sequence) async* {
    yield 1.0;
  }
}
