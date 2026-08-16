import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../runtime/persistent/persistent_operation_log.dart';
import '../../runtime/scribe_mind_runtime.dart';
import '../../runtime/mind_runtime.dart';

/// The [MindRuntime] Audio Scribe (and, as they land, other assistant
/// surfaces) writes operations against.
///
/// Uses [ScribeMindRuntime] with a durable JSON-lines log shared with
/// [MindService] (`sharedMindOperationLog`). `RustMindRuntime.log` remains
/// unimplemented (#1213); this is the Wave 2 wire-up until that lands.
final mindRuntimeProvider = Provider<MindRuntime>(
  (ref) => ScribeMindRuntime(log: sharedMindOperationLog()),
);
