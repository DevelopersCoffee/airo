import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import '../features/feature_registry.dart';
import 'deferred_startup_task.dart';

typedef AppStartupInitializer = Future<void> Function();

/// Primes authentication state after the first frame.
///
/// Route redirects still initialize auth before making auth decisions, so this
/// task is a best-effort warmup rather than a first-frame requirement.
void scheduleDeferredAuthInitialization({
  AppStartupInitializer? initializeAuth,
  void Function(DeferredStartupFrameCallback callback)? addPostFrameCallback,
  void Function(String message)? log,
}) {
  scheduleDeferredStartupTask(
    debugName: 'auth_initialization',
    addPostFrameCallback: addPostFrameCallback,
    log: log,
    task: initializeAuth ?? AuthService.instance.initialize,
  );
}

/// Initializes registered feature modules after the first frame.
void scheduleDeferredFeatureInitialization({
  AppStartupInitializer? initializeFeatures,
  void Function(DeferredStartupFrameCallback callback)? addPostFrameCallback,
  void Function(String message)? log,
}) {
  scheduleDeferredStartupTask(
    debugName: 'feature_initialization',
    addPostFrameCallback: addPostFrameCallback,
    log: log,
    task: initializeFeatures ?? FeatureRegistry.initializeAll,
  );
}

/// Initializes optional audio services after the first frame.
void scheduleDeferredAudioInitialization({
  required AppStartupInitializer initializeAudio,
  bool skipOnWeb = false,
  bool isWeb = kIsWeb,
  void Function(DeferredStartupFrameCallback callback)? addPostFrameCallback,
  void Function(String message)? log,
}) {
  if (skipOnWeb && isWeb) return;

  scheduleDeferredStartupTask(
    debugName: 'audio_initialization',
    addPostFrameCallback: addPostFrameCallback,
    log: log,
    task: initializeAudio,
  );
}
