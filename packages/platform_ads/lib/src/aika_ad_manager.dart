import 'package:core_app_shell/core_app_shell.dart';
import 'package:flutter/foundation.dart';

import 'aika_ad_policy.dart';
import 'aika_ad_sdk.dart';

/// Session-scoped AdMob gate for Aika Stream & Airo apps.
///
/// Initializes Mobile Ads only on Android/iOS phone & tablet profiles. Leanback,
/// web, and desktop never load the SDK.
class AikaAdManager {
  AikaAdManager._({AikaAdPolicy? policy, AikaAdSdk? sdk})
    : policy = policy ?? AikaAdPolicy(),
      _sdk = sdk ?? const AikaAdSdk();

  @visibleForTesting
  factory AikaAdManager.test({AikaAdPolicy? policy, AikaAdSdk? sdk}) {
    return AikaAdManager._(policy: policy, sdk: sdk);
  }

  static final AikaAdManager instance = AikaAdManager._();

  final AikaAdPolicy policy;
  final AikaAdSdk _sdk;

  bool _sdkReady = false;
  Future<void>? _initializing;

  bool get isSdkReady => _sdkReady;

  Future<void> initialize({
    DeviceFormFactor? formFactor,
    Future<DeviceFormFactor> Function()? detectFormFactor,
  }) {
    if (kIsWeb || _sdkReady) {
      return Future<void>.value();
    }
    return _initializing ??= _initialize(
      formFactor: formFactor,
      detectFormFactor: detectFormFactor,
    );
  }

  Future<void> _initialize({
    DeviceFormFactor? formFactor,
    Future<DeviceFormFactor> Function()? detectFormFactor,
  }) async {
    final detected =
        formFactor ??
        await (detectFormFactor ??
            () => DeviceFormFactorDetector.detect(null))();
    if (detected == DeviceFormFactor.tv ||
        detected == DeviceFormFactor.desktop) {
      return;
    }
    if (!await _sdk.initialize()) {
      return;
    }
    _sdkReady = true;
    policy.startSession();
  }

  bool shouldShowAd({required bool isLeanback, required bool isCasting}) {
    return policy.canShow(
      isWeb: kIsWeb,
      isLeanback: isLeanback,
      isCasting: isCasting,
      sdkReady: _sdkReady,
    );
  }

  void recordAdImpression() {
    policy.recordImpression();
  }
}
