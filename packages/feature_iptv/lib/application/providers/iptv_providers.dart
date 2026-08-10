import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import "package:platform_favorites/platform_favorites.dart";
import "package:platform_history/platform_history.dart";
import "package:platform_channels/platform_channels.dart";
import "package:platform_epg/platform_epg.dart";
import "package:platform_player/platform_player.dart";
import "package:platform_media/platform_media.dart";
import 'package:platform_device_profile/platform_device_profile.dart';
import "package:platform_playlist/platform_playlist.dart";
import "package:platform_playlist_import/platform_playlist_import.dart";
import '../content_source_store.dart';
import '../mutable_xmltv_compact_epg_repository.dart';
import '../../domain/favorite_reimport_coordinator.dart';
import '../../domain/channel_region_availability.dart';
import '../../domain/vod_resume_coordinator.dart';
import 'content_source_providers.dart';
import 'provider_health_providers.dart';
import 'channel_library_merger_extension_point.dart';

export 'iptv_cast_providers.dart';
export 'airo_tv_profile_provider.dart';
export 'connectivity_providers.dart';
export 'edge_intelligence_providers.dart';
export 'iptv_navigation_provider.dart';
export 'voice_search_provider.dart';

/// Shared preferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'Override in main with SharedPreferences.getInstance()',
  );
});

final hostPlatformRegionSignalProvider = Provider<HostPlatformRegionSignal>((
  ref,
) {
  return HostPlatformRegionSignal();
});

final regionLocaleCountryProvider = Provider<String?>((ref) {
  return PlatformDispatcher.instance.locale.countryCode;
});

/// Privacy-safe runtime region. Network lookup is intentionally absent from
/// the production composition; SIM and locale answers short-circuit locally.
final regionResolutionProvider = FutureProvider<RegionResolution>((ref) {
  return RegionResolver(
    simCountry: ref.watch(hostPlatformRegionSignalProvider).simCountry,
    localeCountry: () async => ref.read(regionLocaleCountryProvider),
  ).resolve();
});

final channelRegionAvailabilityProvider =
    Provider.family<ChannelRegionAvailability, IPTVChannel>((ref, channel) {
      final country = ref.watch(regionResolutionProvider).value?.countryCode;
      return classifyChannelRegion(channel, country);
    });

/// Global fullscreen mode provider - when true, hides bottom navigation and app bar
final isFullscreenModeProvider = StateProvider<bool>((ref) => false);

/// Dio HTTP client provider
final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
});

/// M3U Parser service provider (legacy - for backward compatibility)
final m3uParserProvider = Provider<M3UParserService>((ref) {
  return M3UParserService(
    dio: ref.watch(dioProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

/// Persists the user's configured content sources, backed by the same local
/// preferences store as the legacy single-playlist setting.
final contentSourceStoreProvider = Provider<ContentSourceStore>((ref) {
  return ContentSourceStore(
    PreferencesStore(ref.watch(sharedPreferencesProvider)),
  );
});

/// Platform-local media stays behind a capability probe so unsupported TV
/// targets never render a non-functional USB action.
final localMediaLibraryAdapterProvider = Provider<LocalMediaLibraryAdapter>((
  ref,
) {
  return const AndroidLocalMediaLibraryAdapter();
});

final dlnaUpnpLibraryAdapterProvider = Provider<DlnaUpnpLibraryAdapter>((ref) {
  return const AndroidDlnaUpnpLibraryAdapter();
});

final localMediaLibraryCapabilitiesProvider =
    FutureProvider<LocalMediaLibraryCapabilities>((ref) {
      return ref.watch(localMediaLibraryAdapterProvider).capabilities();
    });

final personalChannelRepositoryProvider = Provider<PersonalChannelRepository>((
  ref,
) {
  return PersonalChannelRepository(
    PreferencesStore(ref.watch(sharedPreferencesProvider)),
  );
});

final personalChannelsProvider = FutureProvider<List<IPTVChannel>>((ref) {
  return ref.watch(personalChannelRepositoryProvider).list();
});

/// All configured content sources.
///
/// The first read performs an additive migration of the legacy single M3U URL.
/// The old value remains in place for rollback compatibility; source-aware
/// loading uses the new record and therefore does not fetch it twice.
final configuredContentSourcesProvider =
    FutureProvider<List<ContentSourceConfig>>((ref) async {
      final store = ref.watch(contentSourceStoreProvider);
      final sources = await store.getAll();
      final legacyUrl = ref.watch(m3uParserProvider).getPlaylistUrl();
      if (legacyUrl == null ||
          sources.any(
            (source) =>
                source.kind == ContentSourceKind.m3u && source.url == legacyUrl,
          )) {
        return sources;
      }

      var id = 'm3u-legacy-primary';
      var suffix = 1;
      final existingIds = sources.map((source) => source.id).toSet();
      while (existingIds.contains(id)) {
        id = 'm3u-legacy-primary-${suffix++}';
      }
      final uri = Uri.tryParse(legacyUrl);
      final config = ContentSourceConfig(
        id: id,
        kind: ContentSourceKind.m3u,
        label: uri?.host == 'iptv-org.github.io' ? 'IPTV.org' : 'My Playlist',
        url: legacyUrl,
      );
      await store.add(config);
      return List.unmodifiable([...sources, config]);
    });

/// The one configured source whose channels own the browse/runtime surface.
///
/// Existing installs are migrated deterministically to their first configured
/// source. Once selected, no unrelated public catalog or legacy M3U state is
/// merged into the active source's channels.
final activeContentSourceProvider = FutureProvider<ContentSourceConfig?>((
  ref,
) async {
  final sources = await ref.watch(configuredContentSourcesProvider.future);
  if (sources.isEmpty) return null;
  final store = ref.watch(contentSourceStoreProvider);
  final storedId = await store.getActiveSourceId();
  for (final source in sources) {
    if (source.id == storedId) return source;
  }
  final migrated = sources.first;
  await store.setActiveSourceId(migrated.id);
  return migrated;
});

typedef M3uSourceParserFactory = M3UParserService Function(String sourceId);

/// Creates an M3U parser whose preferences, HTTP validators, and parsed cache
/// are isolated to one configured source.
final m3uSourceParserFactoryProvider = Provider<M3uSourceParserFactory>((ref) {
  final dio = ref.watch(dioProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return (sourceId) =>
      M3UParserService(dio: dio, prefs: prefs, sourceId: sourceId);
});

/// User-supplied playlist URL.
final userPlaylistUrlProvider = FutureProvider<String?>((ref) async {
  return ref.watch(m3uParserProvider).getPlaylistUrl();
});

/// Channel data service provider (new - fetches preprocessed JSON)
final channelDataServiceProvider = Provider<ChannelDataService>((ref) {
  return ChannelDataService(
    dio: ref.watch(dioProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

/// IPTV Streaming service provider
final iptvStreamingServiceProvider = Provider<VideoPlayerStreamingService>((
  ref,
) {
  final service = VideoPlayerStreamingService(config: StreamingConfig.youtube);
  ref.onDispose(() => service.dispose());
  return service;
});

/// OS media-session delegate supplied by the host application (e.g. the
/// Airo TV shell overrides this with its `audio_service`-backed
/// `TvAudioHandler`). Null on hosts without a media session (web, mobile,
/// tests) — the streaming service treats that as "nothing to report to".
final tvMediaSessionDelegateProvider = Provider<StreamingMediaSessionDelegate?>(
  (ref) => null,
);

/// TV IPTV Streaming service integration provider
///
/// This provider integrates the IPTV streaming service with the host app's
/// media-session delegate (see [tvMediaSessionDelegateProvider]) for
/// background playback on Android TV/Fire TV platforms.
///
/// Aligns with acceptance test [AND-PB-004]: Background Audio Foreground Service
/// - When user switches to another app (home button), audio continues
/// - Notification controls available for play/pause/stop
///
/// The delegate is attached via the service's setter (not a constructor
/// rebuild) so overriding [tvMediaSessionDelegateProvider] never tears down
/// in-flight playback. Something in the widget tree must watch this provider
/// for the wiring to stay live (`IPTVScreen` does).
///
/// Usage:
/// ```dart
/// // On TV platforms, connect streaming service to TV audio handler
/// ref.watch(tvIptvIntegrationProvider);
///
/// // Then use streaming service normally
/// final streamingService = ref.watch(iptvStreamingServiceProvider);
/// await streamingService.playChannel(channel);
/// ```
final tvIptvIntegrationProvider = Provider<void>((ref) {
  final delegate = ref.watch(tvMediaSessionDelegateProvider);
  ref.watch(iptvStreamingServiceProvider).mediaSessionDelegate = delegate;
});

class ContentSourceRuntimeException implements Exception {
  const ContentSourceRuntimeException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef StalkerSourceLoader =
    Future<List<IPTVChannel>> Function(ContentSourceConfig source);

final stalkerSourceLoaderProvider = Provider<StalkerSourceLoader>((ref) {
  final dio = ref.watch(dioProvider);
  return (source) {
    return StalkerContentSourceAdapter(
      StalkerClient(
        dio: dio,
        serverUrl: source.url,
        macAddress: source.macAddress ?? '',
        sourceId: source.id,
      ),
      sourceId: source.id,
    ).loadChannels();
  };
});

/// Opts a channel-derived provider out of Riverpod's automatic retry.
///
/// Two reasons, both observed on the rig Pixel 9 with an unreachable source:
///
/// * A retrying provider stays in `AsyncLoading` with the error attached, so
///   the screen shows its spinner forever and the error state with its Retry
///   button never renders.
/// * Every dependent that retries re-drives the failed ancestor, which
///   re-contacts the dead source. With rails, vod, guide, and metadata
///   enrichment all retrying, one unreachable playlist was refetched several
///   times a second.
///
/// Channel loading is user-initiated and already has an explicit Retry, so a
/// failure must settle as `AsyncError` and stay settled.
Duration? surfaceChannelFailureInsteadOfRetrying(
  int retryCount,
  Object error,
) => null;

/// All runtime channels. A configured active source is exclusive; the public
/// catalog/legacy fallback is used only when no source is configured.
final iptvChannelsProvider = FutureProvider<List<IPTVChannel>>((ref) async {
  final runtimeChannels = await ref.watch(
    _runtimeChannelsProvider(false).future,
  );
  final personalChannels = await ref.watch(personalChannelsProvider.future);
  return mergeChannelLibraries([runtimeChannels, personalChannels]);
}, retry: surfaceChannelFailureInsteadOfRetrying);

final _runtimeChannelsProvider = FutureProvider.family<List<IPTVChannel>, bool>(
  (ref, forceRefresh) async {
    // Live TV never gates on a single "active" source — every configured
    // library contributes, and the public catalog / legacy parser fills
    // in behind them. See
    // docs/superpowers/specs/2026-08-10-iptv-unified-playlist-merge-design.md.
    List<IPTVChannel> primaryChannels = const [];
    final channelDataService = ref.watch(channelDataServiceProvider);
    try {
      final channels = await channelDataService.fetchChannels(
        forceRefresh: forceRefresh,
      );
      if (channels.isNotEmpty) {
        primaryChannels = channels;
      }
    } catch (e) {
      debugPrint(
        '[Provider] ChannelDataService failed, falling back to M3U: $e',
      );
    }

    // A total configured-source failure must not hide channels another library
    // still has, so hold the error and only report it if nothing else loaded.
    var configuredM3uChannels = const <IPTVChannel>[];
    Object? configuredM3uFailure;
    StackTrace? configuredM3uTrace;
    try {
      configuredM3uChannels = await ref.watch(
        configuredM3uChannelsProvider.future,
      );
    } catch (error, stackTrace) {
      configuredM3uFailure = error;
      configuredM3uTrace = stackTrace;
    }

    if (primaryChannels.isEmpty && configuredM3uChannels.isEmpty) {
      // Fallback to legacy M3U parser.
      primaryChannels = await ref
          .watch(m3uParserProvider)
          .fetchPlaylist(forceRefresh: forceRefresh);
    }

    List<IPTVChannel> byocChannels = const [];
    try {
      byocChannels = await ref.watch(configuredXtreamChannelsProvider.future);
    } catch (e) {
      debugPrint('[Provider] Xtream sources could not be refreshed: $e');
    }

    List<IPTVChannel> stalkerChannels = const [];
    try {
      stalkerChannels = await ref.watch(
        configuredStalkerChannelsProvider.future,
      );
    } catch (e) {
      debugPrint('[Provider] Stalker sources could not be refreshed: $e');
    }

    final merge = ref.watch(channelLibraryMergerProvider);
    final merged = merge([
      primaryChannels,
      configuredM3uChannels,
      byocChannels,
      stalkerChannels,
    ]);
    if (merged.isEmpty && configuredM3uFailure != null) {
      Error.throwWithStackTrace(configuredM3uFailure, configuredM3uTrace!);
    }
    return merged;
  },
  retry: surfaceChannelFailureInsteadOfRetrying,
);

/// Loads every configured M3U source with an independent cache namespace.
///
/// Sources are intentionally processed one at a time. Large public playlists
/// can already occupy meaningful memory while parsing; serial loading keeps
/// peak memory bounded on touch devices while still allowing a failed source
/// to fall back to its own cache and leave sibling sources usable.
final configuredM3uChannelsProvider = FutureProvider<List<IPTVChannel>>((
  ref,
) async {
  final configs = await ref.watch(configuredContentSourcesProvider.future);
  return _loadConfiguredM3uChannels(
    configs,
    ref.read(m3uSourceParserFactoryProvider),
  );
}, retry: surfaceChannelFailureInsteadOfRetrying);

Future<List<IPTVChannel>> _loadConfiguredM3uChannels(
  List<ContentSourceConfig> configs,
  M3uSourceParserFactory parserFactory, {
  bool forceRefresh = false,
  bool failFast = false,
}) async {
  final m3uConfigs = configs
      .where((source) => source.kind == ContentSourceKind.m3u)
      .toList(growable: false);
  if (m3uConfigs.isEmpty) return const [];

  final channels = <IPTVChannel>[];
  var failedSources = 0;
  for (final config in m3uConfigs) {
    final parser = parserFactory(config.id);
    try {
      if (parser.getPlaylistUrl() != config.url) {
        await parser.setPlaylistUrl(config.url);
      }
      final outcome = await parser.fetchPlaylistOutcome(
        forceRefresh: forceRefresh,
      );
      channels.addAll(outcome.channels);
      if (outcome.sourceUnavailable) {
        // The parser reports an unreachable source rather than throwing, so
        // count it here or a dead source reads as an empty one.
        failedSources++;
        debugPrint(
          '[Provider] M3U source ${config.id} could not be refreshed.',
        );
      }
    } catch (_) {
      if (failFast) {
        throw const ContentSourceRuntimeException(
          'Could not refresh the M3U playlist. Check the URL, then retry.',
        );
      }
      // Source URLs may contain private tokens. Keep diagnostics coarse and
      // continue loading the remaining configured sources.
      failedSources++;
      debugPrint('[Provider] M3U source ${config.id} could not be refreshed.');
    }
  }
  if (channels.isEmpty && failedSources == m3uConfigs.length) {
    // Every configured source failed and none had a usable cache. Returning an
    // empty list here renders the "Add your playlist" empty state, which tells
    // a user who already added sources to add them again. Surface it so the
    // screen shows its error state and Retry instead.
    throw PlaylistSourcesUnavailableException(failedSources);
  }
  return mergeChannelLibraries([channels]);
}

/// Thrown when every configured playlist source failed to load and no cached
/// copy was usable. Carries only a count: source URLs can embed private tokens
/// and must not reach logs or the UI.
class PlaylistSourcesUnavailableException implements Exception {
  const PlaylistSourcesUnavailableException(this.sourceCount);

  /// Number of configured sources that failed.
  final int sourceCount;

  @override
  String toString() => sourceCount == 1
      ? 'Your playlist source could not be loaded. Check your connection and '
            'retry.'
      : 'None of your $sourceCount playlist sources could be loaded. Check '
            'your connection and retry.';
}

/// Re-runs the channel libraries after a load failure.
///
/// Invalidating only [iptvChannelsProvider] replays its dependency's cached
/// error, so a retry that touches just the merged provider looks like it did
/// nothing. The source loaders have to be invalidated with it.
void invalidateChannelLibraries(WidgetRef ref) {
  ref.invalidate(configuredM3uChannelsProvider);
  ref.invalidate(configuredXtreamChannelsProvider);
  ref.invalidate(configuredStalkerChannelsProvider);
  // The runtime family caches the composed result, so leaving it alone would
  // replay its stored error and Retry would never reach the source again.
  ref.invalidate(_runtimeChannelsProvider);
  ref.invalidate(iptvChannelsProvider);
}

final configuredXtreamChannelsProvider = FutureProvider<List<IPTVChannel>>((
  ref,
) async {
  final configs = await ref.watch(configuredContentSourcesProvider.future);
  return _loadConfiguredXtreamChannels(
    configs,
    credentials: ref.read(contentSourceCredentialStoreProvider),
    dio: ref.read(dioProvider),
    epgRepository: ref.read(compactEpgRepositoryProvider),
    healthTracker: ref.read(providerHealthTrackerProvider),
  );
});

Future<List<IPTVChannel>> _loadConfiguredXtreamChannels(
  List<ContentSourceConfig> configs, {
  required ContentSourceCredentialStore credentials,
  required Dio dio,
  required CompactEpgRepository epgRepository,
  required ProviderHealthTracker healthTracker,
  bool failFast = false,
}) async {
  final xtreamConfigs = configs
      .where((source) => source.kind == ContentSourceKind.xtream)
      .toList(growable: false);
  if (xtreamConfigs.isEmpty) return const [];
  final channels = <IPTVChannel>[];
  for (final config in xtreamConfigs) {
    final secret = await credentials.read(
      ContentSourceCredentialRef(config.id),
    );
    if (secret == null) {
      if (failFast) {
        throw const ContentSourceRuntimeException(
          'Xtream credentials are unavailable. Reconnect the source.',
        );
      }
      continue;
    }
    try {
      final client = XtreamClient(
        dio: dio,
        serverUrl: config.url,
        username: secret.username,
        password: secret.password,
        healthTracker: healthTracker,
        sourceId: config.id,
      );
      channels.addAll(
        await XtreamContentSourceAdapter(
          client,
          sourceId: config.id,
        ).loadChannels(),
      );
      if (epgRepository is MutableXmltvCompactEpgRepository) {
        final prefix = '${config.id}-';
        epgRepository.updateNamedSource(
          sourceId: 'epg-${config.id}',
          priority: 0,
          repository: XtreamEpgRepository(
            client,
            channelIdToStreamId: (channelId) => channelId.startsWith(prefix)
                ? int.tryParse(channelId.substring(prefix.length))
                : null,
          ),
        );
      }
    } catch (_) {
      if (failFast) {
        throw const ContentSourceRuntimeException(
          'Could not refresh the Xtream source. '
          'Check the server and credentials, then retry.',
        );
      }
      // Dio errors may contain a credential-bearing query URL. Keep
      // diagnostics deliberately coarse and continue with other sources.
      debugPrint(
        '[Provider] Xtream source ${config.id} could not be refreshed.',
      );
    }
  }
  return channels;
}

/// Loads every configured Stalker source, mirroring
/// [configuredM3uChannelsProvider] and [configuredXtreamChannelsProvider]:
/// one dead portal must not blank the others.
final configuredStalkerChannelsProvider = FutureProvider<List<IPTVChannel>>((
  ref,
) async {
  final configs = await ref.watch(configuredContentSourcesProvider.future);
  final stalkerConfigs = configs
      .where((source) => source.kind == ContentSourceKind.stalker)
      .toList(growable: false);
  if (stalkerConfigs.isEmpty) return const [];

  final loader = ref.read(stalkerSourceLoaderProvider);
  final channels = <IPTVChannel>[];
  for (final config in stalkerConfigs) {
    try {
      channels.addAll(await loader(config));
    } catch (_) {
      // Stalker portal URLs and MAC addresses are not secrets by
      // themselves, but keep diagnostics coarse for consistency with
      // the M3U/Xtream loaders above.
      debugPrint(
        '[Provider] Stalker source ${config.id} could not be refreshed.',
      );
    }
  }
  return channels;
});

/// Refresh channels provider
final refreshChannelsProvider = FutureProvider.family<List<IPTVChannel>, bool>((
  ref,
  forceRefresh,
) async {
  // Snapshot before the refresh so CV-017's favorite remap has an "old"
  // list to diff the freshly re-imported one against. Reads whatever is
  // already cached without forcing a fetch -- null/absent on the very
  // first import, which applyFavoriteRemapOnReimport treats as a no-op.
  final oldChannels = ref.read(iptvChannelsProvider).value ?? const [];

  final runtimeChannels = await ref.watch(
    _runtimeChannelsProvider(forceRefresh).future,
  );
  final personalChannels = await ref.watch(personalChannelsProvider.future);
  final newChannels = mergeChannelLibraries([
    runtimeChannels,
    personalChannels,
  ]);

  final needsReview = await applyFavoriteRemapOnReimport(
    favoriteStorage: ref.read(favoriteChannelsStorageProvider),
    coordinator: ref.read(favoriteReimportCoordinatorProvider),
    oldChannels: oldChannels,
    newChannels: newChannels,
  );
  if (needsReview.isNotEmpty) {
    ref.read(favoriteReimportReviewCandidatesProvider.notifier).state =
        needsReview;
  }
  ref.invalidate(favoriteChannelIdsProvider);

  return newChannels;
});

/// Current category filter
final selectedCategoryProvider = StateProvider<ChannelCategory>((ref) {
  return ChannelCategory.all;
});

/// Current flavor filter (taste-based filtering)
final selectedFlavorProvider = StateProvider<ChannelFlavor?>((ref) {
  return null; // null means no flavor filter
});

/// Search query provider
final channelSearchQueryProvider = StateProvider<String>((ref) => '');

/// User preference keywords for channel sorting
final preferenceKeywordsProvider = StateProvider<List<String>>((ref) {
  return const [
    'news',
    'music',
    'sports',
    'radio',
    'local',
    'public',
    'education',
  ];
});

/// Reusable platform search index for the loaded channel list.
final channelSearchIndexProvider = Provider<AiroChannelSearchIndex?>((ref) {
  final channelsAsync = ref.watch(iptvChannelsProvider);
  return channelsAsync.when(
    data: AiroChannelSearchIndex.new,
    loading: () => null,
    error: (_, _) => null,
  );
});

/// Filtered and sorted channels
final filteredChannelsProvider = Provider<List<IPTVChannel>>((ref) {
  final searchIndex = ref.watch(channelSearchIndexProvider);
  final category = ref.watch(selectedCategoryProvider);
  final flavor = ref.watch(selectedFlavorProvider);
  final searchQuery = ref.watch(channelSearchQueryProvider);
  final preferences = ref.watch(preferenceKeywordsProvider);
  // CV-021: hidden groups are excluded from browse by default, not just
  // visually skipped. `.value` is null while the async read is still in
  // flight, which is treated the same as "nothing hidden yet" rather than
  // blocking the whole browse list on it.
  final hiddenGroupIds =
      ref.watch(hiddenGroupIdsProvider).value ?? const <String>{};

  final channels =
      searchIndex?.filterAndSort(
        category: category,
        flavor: flavor,
        query: searchQuery,
        preferenceKeywords: preferences,
      ) ??
      const [];

  final visible = hiddenGroupIds.isEmpty
      ? channels
      : channels
            .where((channel) => !hiddenGroupIds.contains(channel.group))
            .toList(growable: false);
  return sortChannelsForRegion(
    visible,
    ref.watch(regionResolutionProvider).value?.countryCode,
  );
});

/// Channels filtered by specific flavor
final channelsByFlavorProvider =
    Provider.family<List<IPTVChannel>, ChannelFlavor>((ref, flavor) {
      final searchIndex = ref.watch(channelSearchIndexProvider);
      return searchIndex?.channelsByFlavor(flavor) ?? const [];
    });

/// Hindi music channels provider (convenience)
final hindiMusicChannelsProvider = Provider<List<IPTVChannel>>((ref) {
  return ref.watch(channelsByFlavorProvider(ChannelFlavor.hindiMusic));
});

/// English music channels provider (convenience)
final englishMusicChannelsProvider = Provider<List<IPTVChannel>>((ref) {
  return ref.watch(channelsByFlavorProvider(ChannelFlavor.englishMusic));
});

/// Hindi news channels provider (convenience)
final hindiNewsChannelsProvider = Provider<List<IPTVChannel>>((ref) {
  return ref.watch(channelsByFlavorProvider(ChannelFlavor.hindiNews));
});

/// English news channels provider (convenience)
final englishNewsChannelsProvider = Provider<List<IPTVChannel>>((ref) {
  return ref.watch(channelsByFlavorProvider(ChannelFlavor.englishNews));
});

/// Category counts provider - shows how many channels in each category
final categoryCounts = Provider<Map<ChannelCategory, int>>((ref) {
  final searchIndex = ref.watch(channelSearchIndexProvider);
  return searchIndex?.categoryCounts ?? const {};
});

/// Check if any filter is active (category, flavor, or search)
final hasActiveFilterProvider = Provider<bool>((ref) {
  final category = ref.watch(selectedCategoryProvider);
  final flavor = ref.watch(selectedFlavorProvider);
  final searchQuery = ref.watch(channelSearchQueryProvider);
  return category != ChannelCategory.all ||
      flavor != null ||
      searchQuery.isNotEmpty;
});

/// Flavor counts provider - shows how many channels in each flavor
final flavorCounts = Provider<Map<ChannelFlavor, int>>((ref) {
  final searchIndex = ref.watch(channelSearchIndexProvider);
  return searchIndex?.flavorCounts ?? const {};
});

class CompactEpgChannelQuery {
  const CompactEpgChannelQuery({required this.channelIds, required this.now});

  final List<String> channelIds;
  final DateTime now;

  @override
  bool operator ==(Object other) {
    return other is CompactEpgChannelQuery &&
        listEquals(other.channelIds, channelIds) &&
        other.now == now;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(channelIds), now);
}

/// Platform compact EPG repository consumed by Airo TV.
///
/// Apps can override this with `XmltvCompactEpgRepository`, a storage-backed
/// repository, or a delegated compact EPG source. The default keeps guide UI
/// unavailable without parsing XMLTV in presentation code.
final compactEpgRepositoryProvider = Provider<CompactEpgRepository>((ref) {
  return const EmptyCompactEpgRepository();
});

/// Reference time for current/next guide queries.
final compactEpgReferenceTimeProvider = Provider<DateTime>((ref) {
  return DateTime.now().toUtc();
});

final compactEpgSliceForChannelsProvider =
    FutureProvider.family<CompactEpgSlice, CompactEpgChannelQuery>((
      ref,
      query,
    ) async {
      final repository = ref.watch(compactEpgRepositoryProvider);
      return repository.loadCurrentNext(
        channelIds: query.channelIds,
        now: query.now,
      );
    });

/// Bounded guide-window lookup (CV-015): programmes intersecting
/// [GuideWindowQuery]'s time range, per channel — never the full timetable.
final compactEpgWindowProvider =
    FutureProvider.family<CompactEpgWindow, GuideWindowQuery>((
      ref,
      query,
    ) async {
      final repository = ref.watch(compactEpgRepositoryProvider);
      return repository.loadWindow(query);
    });

/// Raw streaming state events from the player service.
final streamingStateStreamProvider = Provider<Stream<StreamingState>>((ref) {
  final service = ref.watch(iptvStreamingServiceProvider);
  return service.stateStream;
});

/// Streaming state provider
final streamingStateProvider = StreamProvider<StreamingState>((ref) {
  return ref.watch(streamingStateStreamProvider);
});

/// Current app lifecycle state, updated by a `WidgetsBindingObserver` in
/// `IPTVScreen`. Drives [PlayerBackgroundingCoordinator]'s PiP / audio-only
/// backgrounding decision.
final appLifecycleStateProvider = StateProvider<AppLifecycleState>(
  (ref) => AppLifecycleState.resumed,
);

/// Whether the app is currently in system Picture-in-Picture mode (#1002).
/// Mirrored from the single native state-change subscription owned by
/// [playerBackgroundingCoordinatorProvider] — widgets watch this to switch
/// to a video-only layout while the PiP window is up.
final pictureInPictureActiveProvider = StateProvider<bool>((ref) => false);

/// Current channel provider
final currentChannelProvider = Provider<IPTVChannel?>((ref) {
  final state = ref.watch(streamingStateProvider);
  return state.when(
    data: (s) => s.currentChannel,
    loading: () => null,
    error: (_, _) => null,
  );
});

/// Current channel index in filtered list
final currentChannelIndexProvider = Provider<int>((ref) {
  final currentChannel = ref.watch(currentChannelProvider);
  final filteredChannels = ref.watch(filteredChannelsProvider);
  if (currentChannel == null) return -1;
  return filteredChannels.indexWhere(
    (c) => c.streamUrl == currentChannel.streamUrl,
  );
});

/// Next channel provider - returns the next channel in the filtered list
final nextChannelProvider = Provider<IPTVChannel?>((ref) {
  final currentIndex = ref.watch(currentChannelIndexProvider);
  final filteredChannels = ref.watch(filteredChannelsProvider);
  if (currentIndex < 0 || filteredChannels.isEmpty) return null;
  final nextIndex = (currentIndex + 1) % filteredChannels.length;
  return filteredChannels[nextIndex];
});

/// Previous channel provider - returns the previous channel in the filtered list
final previousChannelProvider = Provider<IPTVChannel?>((ref) {
  final currentIndex = ref.watch(currentChannelIndexProvider);
  final filteredChannels = ref.watch(filteredChannelsProvider);
  if (currentIndex < 0 || filteredChannels.isEmpty) return null;
  final prevIndex = currentIndex == 0
      ? filteredChannels.length - 1
      : currentIndex - 1;
  return filteredChannels[prevIndex];
});

IPTVChannel? channelAfter({
  required IPTVChannel? currentChannel,
  required List<IPTVChannel> channels,
  required bool Function(IPTVChannel channel) canUseChannel,
}) {
  if (currentChannel == null || channels.isEmpty) return null;
  final currentIndex = channels.indexWhere(
    (channel) => channel.streamUrl == currentChannel.streamUrl,
  );
  if (currentIndex < 0) return null;
  for (var offset = 1; offset < channels.length; offset++) {
    final candidate = channels[(currentIndex + offset) % channels.length];
    if (canUseChannel(candidate)) return candidate;
  }
  return null;
}

IPTVChannel? channelBefore({
  required IPTVChannel? currentChannel,
  required List<IPTVChannel> channels,
  required bool Function(IPTVChannel channel) canUseChannel,
}) {
  if (currentChannel == null || channels.isEmpty) return null;
  final currentIndex = channels.indexWhere(
    (channel) => channel.streamUrl == currentChannel.streamUrl,
  );
  if (currentIndex < 0) return null;
  for (var offset = 1; offset < channels.length; offset++) {
    final candidate =
        channels[(currentIndex - offset + channels.length) % channels.length];
    if (canUseChannel(candidate)) return candidate;
  }
  return null;
}

/// Playback state provider
final playbackStateProvider = Provider<PlaybackState>((ref) {
  final state = ref.watch(streamingStateProvider);
  return state.when(
    data: (s) => s.playbackState,
    loading: () => PlaybackState.idle,
    error: (_, _) => PlaybackState.error,
  );
});

/// Buffer status provider
final bufferStatusProvider = Provider<BufferStatus>((ref) {
  final state = ref.watch(streamingStateProvider);
  return state.when(
    data: (s) => s.bufferStatus,
    loading: () => const BufferStatus(),
    error: (_, _) => const BufferStatus(),
  );
});

/// Current quality provider
final currentQualityProvider = Provider<VideoQuality>((ref) {
  final state = ref.watch(streamingStateProvider);
  return state.when(
    data: (s) => s.currentQuality,
    loading: () => VideoQuality.auto,
    error: (_, _) => VideoQuality.auto,
  );
});

/// Network quality provider
final networkQualityProvider = Provider<NetworkQuality>((ref) {
  final state = ref.watch(streamingStateProvider);
  return state.when(
    data: (s) => s.metrics?.networkQuality ?? NetworkQuality.good,
    loading: () => NetworkQuality.good,
    error: (_, _) => NetworkQuality.offline,
  );
});

// =============================================================================
// Recently Watched Channels Providers
// =============================================================================

/// Recently watched channels storage provider
final recentlyWatchedStorageProvider = Provider<RecentlyWatchedStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return RecentlyWatchedStorage(prefs);
});

/// Recently watched channels provider
/// Returns the list of recently watched channels (most recent first)
final recentlyWatchedChannelsProvider = FutureProvider<List<IPTVChannel>>((
  ref,
) async {
  final storage = ref.watch(recentlyWatchedStorageProvider);
  return storage.getRecentlyWatched(limit: 10);
});

/// Clear recently watched channels
/// Call this to clear the viewing history for privacy
final clearRecentlyWatchedProvider = FutureProvider.family<void, void>((
  ref,
  _,
) async {
  final storage = ref.watch(recentlyWatchedStorageProvider);
  await storage.clearRecent();
  ref.invalidate(recentlyWatchedChannelsProvider);
});

/// Add channel to recently watched
/// Use this when a channel starts playing
final addToRecentlyWatchedProvider = FutureProvider.family<void, IPTVChannel>((
  ref,
  channel,
) async {
  final storage = ref.watch(recentlyWatchedStorageProvider);
  await storage.addToRecent(channel);
  ref.invalidate(recentlyWatchedChannelsProvider);
});

// =============================================================================
// Favorite Channels Providers
// =============================================================================

/// Favorite channels storage provider
final favoriteChannelsStorageProvider = Provider<FavoriteChannelsStorage>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FavoriteChannelsStorage(prefs);
});

/// The set of favorited channel ids.
final favoriteChannelIdsProvider = FutureProvider<Set<String>>((ref) async {
  final storage = ref.watch(favoriteChannelsStorageProvider);
  return storage.getFavoriteChannelIds();
});

/// Whether a specific channel is favorited.
final isChannelFavoriteProvider = Provider.family<bool, String>((
  ref,
  channelId,
) {
  final favoriteIds = ref.watch(favoriteChannelIdsProvider);
  return favoriteIds.value?.contains(channelId) ?? false;
});

/// The list of favorited channels, most-recently-added first.
final favoriteChannelsProvider = FutureProvider<List<IPTVChannel>>((ref) async {
  final favoriteIds = await ref.watch(favoriteChannelIdsProvider.future);
  if (favoriteIds.isEmpty) return const [];

  final allChannels = await ref.watch(iptvChannelsProvider.future);
  return allChannels
      .where((channel) => favoriteIds.contains(channel.id))
      .toList(growable: false);
}, retry: surfaceChannelFailureInsteadOfRetrying);

/// Toggles a channel's favorite state and returns the new state.
///
/// A plain callable rather than a FutureProvider.family: a family instance
/// caches its first result, so a second toggle of the same channel would
/// silently no-op.
final channelFavoriteTogglerProvider = Provider<Future<bool> Function(String)>((
  ref,
) {
  return (channelId) async {
    final storage = ref.read(favoriteChannelsStorageProvider);
    final isNowFavorite = await storage.toggleFavorite(channelId);
    ref.invalidate(favoriteChannelIdsProvider);
    return isNowFavorite;
  };
});

/// Coordinator for CV-017's favorites-survive-reimport behavior.
final favoriteReimportCoordinatorProvider =
    Provider<FavoriteReimportCoordinator>(
      (ref) => FavoriteReimportCoordinator(),
    );

/// Applies [FavoriteReimportCoordinator]'s decisions to real storage: writes
/// high-confidence remaps directly, drops favorites with no match at all,
/// and leaves name-only matches untouched in storage -- returning them so
/// the caller can surface a review prompt (CV-017, #821).
///
/// A no-op when there's nothing to compare against (first import, before
/// any channel list has ever been loaded) or no favorites exist yet.
Future<List<FavoriteReviewCandidate>> applyFavoriteRemapOnReimport({
  required FavoriteChannelsStorage favoriteStorage,
  required FavoriteReimportCoordinator coordinator,
  required List<IPTVChannel> oldChannels,
  required List<IPTVChannel> newChannels,
}) async {
  if (oldChannels.isEmpty) return const [];

  final favoriteIds = await favoriteStorage.getFavoriteChannelIds();
  if (favoriteIds.isEmpty) return const [];

  final result = coordinator.remapFavorites(
    favoriteChannelIds: favoriteIds,
    oldChannels: oldChannels,
    newChannels: newChannels,
  );

  // Ids pending review must stay in storage untouched -- only a true
  // no-match (neither remapped nor flagged for review) gets dropped.
  final reviewIds = result.needsReview
      .map((candidate) => candidate.oldChannel.id)
      .toSet();
  final toDrop = favoriteIds
      .difference(result.remappedFavoriteIds)
      .difference(reviewIds);
  for (final droppedId in toDrop) {
    await favoriteStorage.removeFavorite(droppedId);
  }
  for (final newId in result.remappedFavoriteIds.difference(favoriteIds)) {
    await favoriteStorage.addFavorite(newId);
  }

  return result.needsReview;
}

/// Favorite matches from the most recent re-import that need explicit user
/// confirmation before being applied (CV-017). Cleared by whatever UI
/// eventually consumes and resolves them; empty until then.
final favoriteReimportReviewCandidatesProvider =
    StateProvider<List<FavoriteReviewCandidate>>((ref) => const []);

// =============================================================================
// Hidden Groups Providers (CV-021, #826)
// =============================================================================

/// Hidden groups storage provider.
final hiddenGroupsStorageProvider = Provider<HiddenGroupsStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return HiddenGroupsStorage(prefs);
});

/// The set of hidden group/category ids. Consumed by search (CV-006) and,
/// once it exists, the smart-playlist rule engine (CV-017) so hidden
/// channels are excluded by default rather than just visually skipped.
final hiddenGroupIdsProvider = FutureProvider<Set<String>>((ref) async {
  final storage = ref.watch(hiddenGroupsStorageProvider);
  return storage.getHiddenGroupIds();
});

/// Toggle a group's hidden state. Returns the new state.
final toggleGroupHiddenProvider = FutureProvider.family<bool, String>((
  ref,
  groupId,
) async {
  final storage = ref.watch(hiddenGroupsStorageProvider);
  final nowHidden = await storage.toggleHidden(groupId);
  ref.invalidate(hiddenGroupIdsProvider);
  return nowHidden;
});

// =============================================================================
// VOD Resume Position (CV-016)
// =============================================================================

/// VOD resume-position storage provider.
final vodResumePositionStorageProvider = Provider<VodResumePositionStorage>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return VodResumePositionStorage(prefs);
});

/// Drives VOD resume-seek/save decisions for [VideoPlayerWidget]. Kept alive
/// for the app's lifetime (not per-screen) so [VodResumeCoordinator]'s
/// per-channel "already checked this session" bookkeeping survives
/// navigating away from and back to the player.
final vodResumeCoordinatorProvider = Provider<VodResumeCoordinator>((ref) {
  return VodResumeCoordinator(
    storage: ref.watch(vodResumePositionStorageProvider),
  );
});
