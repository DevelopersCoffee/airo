import 'dart:async';
import 'dart:developer' as developer;
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'resource_scheduler_models.dart';

typedef AiroWorkerComputation<T> = FutureOr<T> Function();

/// Executes CPU-bound platform work away from the UI isolate when available.
///
/// The executor is intentionally small: scheduler policy still decides whether
/// work should run, while this adapter provides the common isolate boundary
/// that parser, EPG, search, and cache jobs can share.
class AiroWorkerExecutor {
  const AiroWorkerExecutor({this.forceInline = false});

  /// Forces same-isolate execution for deterministic tests and unsupported
  /// runtimes.
  final bool forceInline;

  Future<T> run<T>({
    required String debugName,
    required AiroWorkerJobKind kind,
    required AiroWorkerComputation<T> computation,
  }) async {
    final mode = forceInline || kIsWeb ? 'inline' : 'isolate';
    final task = developer.TimelineTask()
      ..start(
        'AiroWorkerExecutor.run',
        arguments: <String, Object?>{
          'debugName': debugName,
          'kind': kind.stableId,
          'mode': mode,
        },
      );

    try {
      if (forceInline || kIsWeb) {
        return await Future<T>.sync(computation);
      }
      return await Isolate.run<T>(computation, debugName: debugName);
    } finally {
      task.finish();
    }
  }
}
