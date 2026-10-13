import 'package:platform_ads/platform_ads.dart';
import 'package:flutter/foundation.dart';

/// Resolves the process-wide [AikaAdManager], with an optional test override.
AikaAdManager resolveAikaAdManager() =>
    _debugAikaAdManager ?? AikaAdManager.instance;

@visibleForTesting
AikaAdManager? _debugAikaAdManager;

@visibleForTesting
void bindAikaAdManagerForTests(AikaAdManager? manager) {
  _debugAikaAdManager = manager;
}
