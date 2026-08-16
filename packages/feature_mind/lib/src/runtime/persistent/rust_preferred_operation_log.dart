import '../models/log_models.dart';
import '../ports/operation_log_port.dart';
import '../rust/rust_mind_runtime_ready.dart';
import '../../whisper/api/mind_runtime.dart';

/// Operation log backed by Rust `airo_mind_core::Runtime` when Mind is ready.
///
/// Falls back to [PersistentOperationLog] for consent ops recorded before
/// `initialize` completes. Legacy JSONL rows migrate into Rust on first boot.
class RustPreferredOperationLog implements OperationLogPort {
  RustPreferredOperationLog(this._fallback);

  final OperationLogPort _fallback;

  bool get _rustReady => mindRuntimeRustReady();

  @override
  Future<int> append({
    required MindOpKind kind,
    required String title,
    required String contextId,
    String detail = '',
  }) async {
    if (!_rustReady) {
      return await _fallback.append(
        kind: kind,
        title: title,
        contextId: contextId,
        detail: detail,
      );
    }
  try {
      final sequence = mindRuntimeAppendScribeOp(
        kind: kind.name,
        title: title,
        contextId: contextId,
        detail: detail,
      );
      return sequence.toInt();
    } on Object {
      return await _fallback.append(
        kind: kind,
        title: title,
        contextId: contextId,
        detail: detail,
      );
    }
  }

  @override
  Future<int> count() async {
    if (!_rustReady) return await _fallback.count();
    try {
      return mindRuntimeScribeOpCount().toInt();
    } on Object {
      return await _fallback.count();
    }
  }

  @override
  Future<List<MindOp>> range({required int offset, required int limit}) async {
    if (!_rustReady) {
      return await _fallback.range(offset: offset, limit: limit);
    }
    try {
      final ops = mindRuntimeScribeOpsRecent(
        offset: BigInt.from(offset),
        limit: BigInt.from(limit),
      );
      return ops
          .map(
            (op) => MindOp(
              sequence: op.sequence.toInt(),
              kind: MindOpKind.values.firstWhere(
                (value) => value.name == op.kind,
                orElse: () => MindOpKind.inference,
              ),
              title: op.title,
              contextId: op.contextId,
              deviceName: op.deviceName,
              signature: SignatureState.unsigned,
              recordedAtMs: op.recordedAtMs.toInt(),
              detail: op.detail,
            ),
          )
          .toList(growable: false);
    } on Object {
      return await _fallback.range(offset: offset, limit: limit);
    }
  }

  @override
  Future<MindOp?> bySequence(int sequence) async {
    final ops = await range(offset: 0, limit: 256);
    for (final op in ops) {
      if (op.sequence == sequence) return op;
    }
    return await _fallback.bySequence(sequence);
  }

  @override
  Future<SignatureState> verify(int sequence) async =>
      (await bySequence(sequence))?.signature ?? SignatureState.unsigned;

  @override
  Stream<double> replayFrom(int sequence) async* {
    if (!_rustReady) {
      yield* _fallback.replayFrom(sequence);
      return;
    }
    try {
      final steps = mindRuntimeReplayFrom(sequence: BigInt.from(sequence));
      for (var index = 0; index < steps.length; index++) {
        yield steps[index];
      }
    } on Object {
      yield* _fallback.replayFrom(sequence);
    }
  }
}
