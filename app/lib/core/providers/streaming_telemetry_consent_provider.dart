import 'package:core_analytics/core_analytics.dart';
import 'package:feature_iptv/feature_iptv.dart' show sharedPreferencesProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 1 (F7.5) — streaming QoE telemetry is opt-in only. Nothing is
/// recorded, even to the local diagnostics sink, until the user
/// explicitly grants this in Settings. `core_analytics` has no
/// persistence of its own (confirmed by investigation — see
/// tasks/tv-zero-copy-cast-phase1-plan.md's P1-2), so app/lib owns this
/// key end to end: [loadStreamingTelemetryConsent] reads it before the
/// `ProviderScope` exists (main_tv.dart bootstrap);
/// [StreamingTelemetryConsentNotifier] writes it from the settings
/// toggle.
const streamingTelemetryConsentStorageKey = 'streaming_telemetry_consent';

/// Deliberately NOT built from [AiroAnalyticsConsentState.localOnly] —
/// that preset's `localOnly` flag is a blanket allowlist restricted to
/// `operational`/`diagnostics` purposes and silently blackholes
/// `playbackQuality` events regardless of that field's own value
/// (`validateEvent`'s `droppedByLocalOnly` gate runs before the
/// per-purpose check). Every field is spelled out explicitly so this
/// doesn't regress if the preset's shape changes.
const _consentGranted = AiroAnalyticsConsentState(
  operational: true,
  product: false,
  playbackQuality: true,
  diagnostics: false,
  crash: false,
  personalized: false,
);

const _consentWithheld = AiroAnalyticsConsentState(
  operational: true,
  product: false,
  playbackQuality: false,
  diagnostics: false,
  crash: false,
  personalized: false,
);

/// Builds the initial consent state for
/// `PlatformMediaLogger.setAnalyticsService` at startup, before the
/// `ProviderScope` (and therefore [streamingTelemetryConsentProvider])
/// exists.
AiroAnalyticsConsentState loadStreamingTelemetryConsent(
  SharedPreferences prefs,
) {
  final granted = prefs.getBool(streamingTelemetryConsentStorageKey) ?? false;
  return granted ? _consentGranted : _consentWithheld;
}

/// The single [AiroLocalDiagnosticsAnalyticsService] instance wired into
/// `AppLogger` at startup (see `main_tv.dart`) — overridden with that
/// exact instance so [StreamingTelemetryConsentNotifier] mutates the
/// live service the engine actually reports through, not a disconnected
/// copy. The default here (withheld consent) only matters for contexts
/// that never override it, e.g. widget tests.
final streamingTelemetryServiceProvider =
    Provider<AiroLocalDiagnosticsAnalyticsService>((ref) {
      return AiroLocalDiagnosticsAnalyticsService(consent: _consentWithheld);
    });

class StreamingTelemetryConsentNotifier extends StateNotifier<bool> {
  final Ref _ref;

  StreamingTelemetryConsentNotifier(this._ref) : super(false) {
    _loadFromStorage();
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _ref
        .read(streamingTelemetryServiceProvider)
        .updateConsent(enabled ? _consentGranted : _consentWithheld);
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      await prefs.setBool(streamingTelemetryConsentStorageKey, enabled);
    } catch (_) {
      // Best-effort persistence -- consent still applies for this
      // session even if the write fails.
    }
  }

  void _loadFromStorage() {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      state = prefs.getBool(streamingTelemetryConsentStorageKey) ?? false;
    } catch (_) {
      // Failed to load, keep default (withheld).
    }
  }
}

final streamingTelemetryConsentProvider =
    StateNotifierProvider<StreamingTelemetryConsentNotifier, bool>(
      (ref) => StreamingTelemetryConsentNotifier(ref),
    );
