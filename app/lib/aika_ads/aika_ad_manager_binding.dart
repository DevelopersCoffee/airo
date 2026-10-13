import 'package:platform_ads/platform_ads.dart';
import 'package:flutter/foundation.dart';

/// Resolves the process-wide [AikaAdManager], with an optional debug override.
AikaAdManager resolveAikaAdManager() {
  if (kDebugMode) {
    final override = _debugAikaAdManager;
    if (override != null) {
      return override;
    }
  }
  return AikaAdManager.instance;
}

AikaAdManager? _debugAikaAdManager;

/// Binds a test [AikaAdManager] in debug builds only; no-op in release.
@visibleForTesting
void bindAikaAdManagerForTests(AikaAdManager? manager) {
  if (!kDebugMode) {
    return;
  }
  _debugAikaAdManager = manager;
}
