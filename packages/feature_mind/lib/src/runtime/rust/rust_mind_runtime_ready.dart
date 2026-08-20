import 'dart:typed_data';

import '../../whisper/api/meetings.dart' show isReady;
import '../../whisper/api/mind_runtime.dart' as rust;
import '../models/log_models.dart';

/// Whether the Mind Rust runtime is initialised without throwing when FRB is
/// not loaded (e.g. widget tests that never call `RustLib.init`).
bool mindRuntimeRustReady() {
  try {
    return isReady();
  } on Object {
    return false;
  }
}

/// Forwards to the generated Mind runtime bridge. Callers live in the
/// persistent log, which must not import `src/api/` itself.
BigInt mindRuntimeAppendScribeOp({
  required String kind,
  required String title,
  required String contextId,
  required String detail,
}) => rust.mindRuntimeAppendScribeOp(
  kind: kind,
  title: title,
  contextId: contextId,
  detail: detail,
);

BigInt mindRuntimeScribeOpCount() => rust.mindRuntimeScribeOpCount();

List<MindOp> mindRuntimeScribeOpsRecent({
  required BigInt offset,
  required BigInt limit,
}) {
  final ops = rust.mindRuntimeScribeOpsRecent(offset: offset, limit: limit);
  return [
    for (final op in ops)
      MindOp(
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
  ];
}

Float64List mindRuntimeReplayFrom({required BigInt sequence}) =>
    rust.mindRuntimeReplayFrom(sequence: sequence);
