/// Frequency and surface rules for Aika Stream native ads.
///
/// Pure Dart so tests do not need `google_mobile_ads`. Ads are in-app UI
/// only: never SSAI, never playlist rewriting, never Cast, never leanback.
class AikaAdPolicy {
  AikaAdPolicy({
    DateTime Function()? clock,
    this.sessionWarmup = const Duration(minutes: 5),
    this.cooldown = const Duration(minutes: 30),
  }) : _clock = clock ?? DateTime.now;

  static const Duration defaultSessionWarmup = Duration(minutes: 5);
  static const Duration defaultCooldown = Duration(minutes: 30);

  final DateTime Function() _clock;
  final Duration sessionWarmup;
  final Duration cooldown;

  DateTime? _sessionStartedAt;
  DateTime? _lastImpressionAt;

  DateTime? get sessionStartedAt => _sessionStartedAt;
  DateTime? get lastImpressionAt => _lastImpressionAt;

  void startSession([DateTime? at]) {
    _sessionStartedAt = at ?? _clock();
  }

  void recordImpression([DateTime? at]) {
    _lastImpressionAt = at ?? _clock();
  }

  AikaAdDecision decide({
    required bool isWeb,
    required bool isLeanback,
    required bool isCasting,
    bool sdkReady = true,
  }) {
    if (isWeb) {
      return const AikaAdDecision.denied('web');
    }
    if (isLeanback) {
      return const AikaAdDecision.denied('leanback');
    }
    if (isCasting) {
      return const AikaAdDecision.denied('cast');
    }
    if (!sdkReady) {
      return const AikaAdDecision.denied('sdk');
    }
    final sessionStart = _sessionStartedAt;
    if (sessionStart == null ||
        _clock().difference(sessionStart) < sessionWarmup) {
      return const AikaAdDecision.denied('warmup');
    }
    final lastImpression = _lastImpressionAt;
    if (lastImpression != null &&
        _clock().difference(lastImpression) < cooldown) {
      return const AikaAdDecision.denied('cooldown');
    }
    return const AikaAdDecision.allowed();
  }

  bool canShow({
    required bool isWeb,
    required bool isLeanback,
    required bool isCasting,
    bool sdkReady = true,
  }) {
    return decide(
      isWeb: isWeb,
      isLeanback: isLeanback,
      isCasting: isCasting,
      sdkReady: sdkReady,
    ).allowed;
  }
}

class AikaAdDecision {
  const AikaAdDecision.allowed() : allowed = true, reason = 'ok';

  const AikaAdDecision.denied(this.reason) : allowed = false;

  final bool allowed;
  final String reason;
}

enum AikaAdPlacement { browse, pause }
