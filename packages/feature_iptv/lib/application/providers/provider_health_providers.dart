import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:platform_playlist/platform_playlist.dart';

import 'iptv_providers.dart' show sharedPreferencesProvider;

const providerHealthStorageKey = 'iptv.provider_health.v1';

/// Changes whenever the shared tracker records or clears a sample.
///
/// Presentation code watches this revision before reading a snapshot so the
/// pure platform tracker does not need a Flutter dependency.
final providerHealthRevisionProvider = StateProvider<int>((ref) => 0);

/// One privacy-safe, bounded provider-health tracker for the application.
///
/// The persisted payload contains source ids, categorical outcomes, timing,
/// and timestamps only. Provider URLs, credentials, response bodies, and raw
/// exception text never enter [ProviderHealthSample].
final providerHealthTrackerProvider = Provider<ProviderHealthTracker>((ref) {
  final preferences = ref.watch(sharedPreferencesProvider);
  late final ProviderHealthTracker tracker;
  tracker = ProviderHealthTracker(
    initialSamples: _decodeSamples(
      preferences.getString(providerHealthStorageKey),
    ),
    onChanged: () {
      ref.read(providerHealthRevisionProvider.notifier).state++;
      preferences.setString(
        providerHealthStorageKey,
        jsonEncode(tracker.samples.map(_encodeSample).toList(growable: false)),
      );
    },
  );
  return tracker;
});

Map<String, Object?> _encodeSample(ProviderHealthSample sample) => {
  'sourceId': sample.sourceId,
  'timestampUtc': sample.timestampUtc.toIso8601String(),
  'kind': sample.kind.name,
  if (sample.latency != null) 'latencyMicros': sample.latency!.inMicroseconds,
  if (sample.httpStatus != null) 'httpStatus': sample.httpStatus,
  if (sample.failureCategory != null) 'failureCategory': sample.failureCategory,
};

List<ProviderHealthSample> _decodeSamples(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map(_decodeSample)
        .whereType<ProviderHealthSample>()
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

ProviderHealthSample? _decodeSample(Map<dynamic, dynamic> value) {
  final sourceId = value['sourceId'];
  final timestampRaw = value['timestampUtc'];
  final kindRaw = value['kind'];
  if (sourceId is! String ||
      sourceId.isEmpty ||
      timestampRaw is! String ||
      kindRaw is! String) {
    return null;
  }
  final timestamp = DateTime.tryParse(timestampRaw)?.toUtc();
  final kind = ProviderHealthEventKind.values
      .where((candidate) => candidate.name == kindRaw)
      .firstOrNull;
  if (timestamp == null || kind == null) return null;

  final latencyMicros = value['latencyMicros'];
  final latency = latencyMicros is int
      ? Duration(microseconds: latencyMicros)
      : null;
  final httpStatus = value['httpStatus'];
  final failureCategory = value['failureCategory'];
  if (kind == ProviderHealthEventKind.fetchFailure &&
      failureCategory is! String) {
    return null;
  }
  return ProviderHealthSample(
    sourceId: sourceId,
    timestampUtc: timestamp,
    kind: kind,
    latency: latency,
    httpStatus: httpStatus is int ? httpStatus : null,
    failureCategory: failureCategory is String ? failureCategory : null,
  );
}
