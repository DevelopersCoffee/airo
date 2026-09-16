import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/streaming_telemetry_consent_provider.dart';

/// Wipes Aika Stream's on-device playback data.
///
/// Source credentials live in [secureStoreProvider]; playlist URLs, favorites,
/// watch history, guide sources, and preferences live in SharedPreferences.
/// There is no developer-hosted account to delete.
Future<void> deleteAikaStreamLocalData(Ref ref) async {
  final sources = List.of(await ref.read(contentSourceStoreProvider).getAll());
  for (final source in sources) {
    await ref.read(removeContentSourceProvider(source.id).future);
  }
  await ref.read(xmltvSourceStoreProvider).clear();
  await ref.read(secureStoreProvider).deleteAll();
  await ref.read(streamingTelemetryConsentProvider.notifier).setEnabled(false);
  await ref.read(sharedPreferencesProvider).clear();
  ref.invalidate(configuredContentSourcesProvider);
  ref.invalidate(activeContentSourceProvider);
  ref.invalidate(recentlyWatchedChannelsProvider);
  ref.invalidate(favoriteChannelIdsProvider);
  ref.invalidate(xmltvSourceConfigProvider);
}

final aikaStreamLocalDataDeleterProvider = Provider<Future<void> Function()>((
  ref,
) {
  return () => deleteAikaStreamLocalData(ref);
});
