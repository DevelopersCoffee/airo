import 'dart:io';

import 'package:core_data/core_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';

import '../epg_channel_match_override_store.dart';
import '../guide_window_query.dart';
import '../mutable_xmltv_compact_epg_repository.dart';
import '../xmltv_source_refresh_service.dart';
import '../xmltv_source_store.dart';
import 'iptv_providers.dart';

final epgChannelMatchOverrideStoreProvider =
    Provider<EpgChannelMatchOverrideStore>((ref) {
      return EpgChannelMatchOverrideStore(
        PreferencesStore(ref.watch(sharedPreferencesProvider)),
      );
    });

final xmltvSourceStoreProvider = Provider<XmltvSourceStore>((ref) {
  return XmltvSourceStore(
    PreferencesStore(ref.watch(sharedPreferencesProvider)),
  );
});

/// One app-lifetime instance — [XmltvSourceRefreshService] mutates it via
/// [MutableXmltvCompactEpgRepository.updateSource]; nothing re-creates it.
final mutableXmltvCompactEpgRepositoryProvider =
    Provider<MutableXmltvCompactEpgRepository>((ref) {
      return MutableXmltvCompactEpgRepository();
    });

final xmltvSourceRefreshServiceProvider = Provider<XmltvSourceRefreshService>((
  ref,
) {
  return XmltvSourceRefreshService(
    dio: ref.watch(dioProvider),
    sourceStore: ref.watch(xmltvSourceStoreProvider),
    repository: ref.watch(mutableXmltvCompactEpgRepositoryProvider),
    downloadDirectoryProvider: () async => Directory.systemTemp,
  );
});

final xmltvSourceConfigProvider = FutureProvider<XmltvSourceConfig?>((
  ref,
) async {
  return ref.watch(xmltvSourceStoreProvider).load();
});

final guideWindowDurationProvider = StateProvider<Duration>(
  (ref) => const Duration(hours: 3),
);

/// "Now," floored to the nearest 30 minutes, so the window doesn't shift on
/// every rebuild — matches the fixed-window UX competitive guides use.
final guideWindowStartProvider = Provider<DateTime>((ref) {
  final now = DateTime.now().toUtc();
  final flooredMinute = now.minute < 30 ? 0 : 30;
  return DateTime.utc(now.year, now.month, now.day, now.hour, flooredMinute);
});

final guideEpgOverridesProvider = FutureProvider<Map<String, String>>((
  ref,
) async {
  return ref.watch(epgChannelMatchOverrideStoreProvider).getOverrides();
});

/// Bounded guide-window query (CV-015) — thin wrapper over
/// [queryGuideWindowWithOverrides] until the paged window provider
/// (Live Grid Navigation) supersedes it.
final guideEpgWindowProvider = FutureProvider<CompactEpgWindow>((ref) async {
  final channels = await ref.watch(iptvChannelsProvider.future);
  final overrides = await ref.watch(guideEpgOverridesProvider.future);
  final hiddenGroupIds = await ref.watch(hiddenGroupIdsProvider.future);
  final windowStart = ref.watch(guideWindowStartProvider);
  final windowDuration = ref.watch(guideWindowDurationProvider);

  return queryGuideWindowWithOverrides(
    channels: channels,
    overrides: overrides,
    hiddenGroupIds: hiddenGroupIds,
    repository: ref.watch(compactEpgRepositoryProvider),
    windowStart: windowStart,
    windowEnd: windowStart.add(windowDuration),
    now: DateTime.now().toUtc(),
  );
});

/// Independent of [channelSearchQueryProvider] (the main Live TV screen's
/// search state) — navigating to the guide must not perturb that screen.
final guideSearchQueryProvider = StateProvider<String>((ref) => '');

/// Reuses [channelSearchIndexProvider]/[AiroChannelSearchIndex] — the same
/// index/algorithm the main channel list uses (CV-006), per this issue's
/// "do not build a second search stack" constraint.
final guideFilteredChannelsProvider = Provider<List<IPTVChannel>>((ref) {
  final index = ref.watch(channelSearchIndexProvider);
  final query = ref.watch(guideSearchQueryProvider);
  final hiddenGroupIds =
      ref.watch(hiddenGroupIdsProvider).value ?? const <String>{};
  if (index == null) return const [];

  final channels = index.filterAndSort(query: query);
  if (hiddenGroupIds.isEmpty) return channels;
  return channels
      .where((channel) => !hiddenGroupIds.contains(channel.group))
      .toList(growable: false);
});
