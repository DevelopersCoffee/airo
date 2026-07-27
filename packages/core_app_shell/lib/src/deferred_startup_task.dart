import 'dart:async';

import 'package:flutter/widgets.dart';

typedef DeferredStartupCallback = FutureOr<void> Function();
typedef DeferredStartupFrameCallback = void Function(Duration timestamp);

/// Schedules non-first-frame startup work after the first frame is queued.
///
/// Startup entrypoints use this for warmups and best-effort service setup that
/// should not block the shell from rendering.
void scheduleDeferredStartupTask({
  required String debugName,
  required DeferredStartupCallback task,
  WidgetsBinding? binding,
  void Function(DeferredStartupFrameCallback callback)? addPostFrameCallback,
  void Function(String message)? log,
}) {
  final schedulePostFrame =
      addPostFrameCallback ??
      (binding ?? WidgetsBinding.instance).addPostFrameCallback;
  final logger = log ?? debugPrint;

  schedulePostFrame((_) {
    unawaited(
      Future<void>.sync(task).then(
        (_) {
          logger('✅ Deferred startup task completed: $debugName');
        },
        onError: (Object error, StackTrace stackTrace) {
          logger('⚠️ Deferred startup task failed: $debugName: $error');
        },
      ),
    );
  });
}
