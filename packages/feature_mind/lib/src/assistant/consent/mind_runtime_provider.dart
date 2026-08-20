import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model_bench/production_model_port.dart';
import '../../runtime/persistent/persistent_operation_log.dart';
import '../../runtime/scribe_mind_runtime.dart';
import '../../runtime/mind_runtime.dart';

/// The [MindRuntime] Audio Scribe (and, as they land, other assistant
/// surfaces) writes operations against.
///
/// Uses [ScribeMindRuntime] with [RustPreferredOperationLog] and
/// [RustMindRuntimeVault] shared with [MindService] (`sharedMindOperationLog`).
/// [ModelPort] is the production GGUF-backed port (load + warmed median bench),
/// not the fixture catalog.
final mindRuntimeProvider = Provider<MindRuntime>(
  (ref) => ScribeMindRuntime(
    log: sharedMindOperationLog(),
    models: createProductionModelPort(),
  ),
);
