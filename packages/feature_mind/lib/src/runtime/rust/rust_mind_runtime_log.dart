import 'dart:typed_data';

import '../../whisper/api/mind_runtime.dart';
import '../models/log_models.dart';

/// Rust-backed operation log seam — the only runtime-layer entry to mind_runtime
/// FFI besides [RustMindRuntimeVault] and [rust_mind_runtime_ready.dart].
BigInt mindRuntimeAppendScribeOpSafe({
  required MindOpKind kind,
  required String title,
  required String contextId,
  String detail = '',
}) =>
    mindRuntimeAppendScribeOp(
      kind: kind.name,
      title: title,
      contextId: contextId,
      detail: detail,
    );

BigInt mindRuntimeScribeOpCountSafe() => mindRuntimeScribeOpCount();

List<MindOpWire> mindRuntimeScribeOpsRecentSafe({
  required int offset,
  required int limit,
}) =>
    mindRuntimeScribeOpsRecent(
      offset: BigInt.from(offset),
      limit: BigInt.from(limit),
    );

Float64List mindRuntimeReplayFromSafe({required int sequence}) =>
    mindRuntimeReplayFrom(sequence: BigInt.from(sequence));
