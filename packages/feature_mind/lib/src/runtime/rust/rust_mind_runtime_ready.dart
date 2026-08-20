import 'dart:typed_data';

import '../../whisper/api/meetings.dart' show isReady;
import '../../whisper/api/mind_runtime.dart' as rust;

export '../../whisper/api/mind_runtime.dart' show MindOpWire;

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

List<rust.MindOpWire> mindRuntimeScribeOpsRecent({
  required BigInt offset,
  required BigInt limit,
}) => rust.mindRuntimeScribeOpsRecent(offset: offset, limit: limit);

Float64List mindRuntimeReplayFrom({required BigInt sequence}) =>
    rust.mindRuntimeReplayFrom(sequence: sequence);
