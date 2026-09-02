import 'dart:io';

import 'package:core_data/core_data.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:platform_playlist_import/platform_playlist_import.dart';
import 'package:platform_worker_jobs/platform_worker_jobs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mutable_xmltv_compact_epg_repository.dart';
import 'xmltv_source_refresh_service.dart';
import 'xmltv_source_store.dart';

Future<bool> seedAiroTvDebugDefaultPlaylist(
  SharedPreferences prefs, {
  required String playlistUrl,
  M3UParserService? parser,
}) async {
  if (playlistUrl.isEmpty) return false;

  final parserService = parser ?? M3UParserService(dio: Dio(), prefs: prefs);
  if (parserService.getPlaylistUrl() != null) return false;

  await parserService.setPlaylistUrl(playlistUrl);
  return true;
}

Future<void> warmAiroTvDebugDefaultPlaylistCache(
  SharedPreferences prefs, {
  required String playlistUrl,
  M3UParserService? parser,
}) async {
  if (playlistUrl.isEmpty) return;

  final parserService = parser ?? M3UParserService(dio: Dio(), prefs: prefs);
  if (parserService.getPlaylistUrl() != playlistUrl) return;

  await parserService.fetchPlaylist(forceRefresh: true);
}

SnapshotBackedCompactEpgRepository createAiroTvCompactEpgRepository({
  Future<Directory> Function()? supportDirectoryProvider,
  CompactEpgRepository? fallback,
}) {
  final directoryProvider =
      supportDirectoryProvider ?? getApplicationSupportDirectory;
  return SnapshotBackedCompactEpgRepository(
    store: FileCompactEpgSnapshotStore(
      fileProvider: () async {
        final supportDir = await directoryProvider();
        return File('${supportDir.path}/epg/compact_epg_snapshot.json');
      },
    ),
    fallback: fallback ?? const EmptyCompactEpgRepository(),
  );
}

Future<Duration?> warmAiroTvDebugDefaultEpgCache(
  SharedPreferences prefs, {
  required SnapshotBackedCompactEpgRepository repository,
  MutableXmltvCompactEpgRepository? windowRepository,
  required String epgUrl,
  M3UParserService? parser,
  Dio? dio,
  Future<Directory> Function()? epgDownloadDirectoryProvider,
  DateTime Function()? clock,
  AiroWorkerExecutor workerExecutor = const AiroWorkerExecutor(),
}) async {
  final normalizedEpgUrl = epgUrl.trim();
  if (normalizedEpgUrl.isEmpty) return null;

  final uri = Uri.tryParse(normalizedEpgUrl);
  if (uri == null ||
      uri.host.isEmpty ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    throw ArgumentError.value(
      epgUrl,
      'epgUrl',
      'Enter a valid HTTP(S) XMLTV EPG URL.',
    );
  }

  final http = dio ?? Dio();
  final parserService = parser ?? M3UParserService(dio: http, prefs: prefs);
  final channels = await parserService.fetchPlaylist();
  if (channels.isEmpty) return null;

  final downloadDirectory =
      await (epgDownloadDirectoryProvider ?? getTemporaryDirectory)();
  await downloadDirectory.create(recursive: true);
  final guideFile = File(
    '${downloadDirectory.path}/airo_tv_debug_epg_${DateTime.now().microsecondsSinceEpoch}.xml',
  );

  try {
    await http.download(
      normalizedEpgUrl,
      guideFile.path,
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(seconds: 30),
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    if (!await guideFile.exists() || await guideFile.length() == 0) {
      return null;
    }

    final stopwatch = Stopwatch()..start();
    final now = (clock ?? DateTime.now)().toUtc();
    final snapshot = await workerExecutor.run<CompactEpgSlice>(
      debugName: 'airo_tv_debug_epg_warmup',
      kind: AiroWorkerJobKind.epgRefresh,
      computation: () async => _buildAiroTvCompactEpgSnapshot(
        xmltvPath: guideFile.path,
        now: now,
        channels: channels,
      ),
    );
    await repository.saveSnapshot(snapshot);
    windowRepository?.updateSource(
      InMemoryCompactEpgRepository(seed: snapshot),
    );
    stopwatch.stop();
    return stopwatch.elapsed;
  } finally {
    if (await guideFile.exists()) {
      await guideFile.delete();
    }
  }
}

Future<void> refreshAiroTvConfiguredXmltvSource(
  SharedPreferences prefs, {
  required MutableXmltvCompactEpgRepository repository,
  Dio? dio,
  XmltvSourceStore? sourceStore,
  Future<Directory> Function()? downloadDirectoryProvider,
}) async {
  final refreshService = XmltvSourceRefreshService(
    dio: dio ?? Dio(),
    sourceStore: sourceStore ?? XmltvSourceStore(PreferencesStore(prefs)),
    repository: repository,
    downloadDirectoryProvider:
        downloadDirectoryProvider ?? getTemporaryDirectory,
  );
  await refreshService.refreshConfiguredSources();
}

/// Refreshes the system (product-default) programme guide for the
/// countries actually present in the loaded playlist, never the whole
/// catalog: after the playlist is parsed, every distinct [IPTVChannel.country]
/// (derived from the playlist's own `tvg-id`, e.g. `MTV.in@SD` -> `IN`) is
/// requested as its own `guide_$CC` shard. A playlist that declares no
/// country on any channel falls back to [country] (the
/// `IPTV_DATA_COUNTRY` dart-define, default `IN`) so a guide still loads.
Future<bool> refreshAiroTvBundledSystemGuide(
  SharedPreferences prefs, {
  required MutableXmltvCompactEpgRepository repository,
  required String bundledPlaylistUrl,
  required String manifestUrl,
  required String country,
  M3UParserService? parser,
  Dio? dio,
  XmltvSourceStore? sourceStore,
  Future<Directory> Function()? downloadDirectoryProvider,
}) async {
  if (bundledPlaylistUrl.isEmpty || manifestUrl.isEmpty) return false;
  final http = dio ?? Dio();
  final parserService = parser ?? M3UParserService(dio: http, prefs: prefs);
  if (parserService.getPlaylistUrl() != bundledPlaylistUrl) return false;
  final channels = await parserService.fetchPlaylist();
  final playlistCountries = {
    for (final channel in channels)
      if (channel.country != null && channel.country!.isNotEmpty)
        channel.country!.toUpperCase(),
  };
  final countries = playlistCountries.isNotEmpty
      ? playlistCountries
      : {country.toUpperCase()};
  final refreshService = XmltvSourceRefreshService(
    dio: http,
    sourceStore: sourceStore ?? XmltvSourceStore(PreferencesStore(prefs)),
    repository: repository,
    downloadDirectoryProvider:
        downloadDirectoryProvider ?? getTemporaryDirectory,
  );
  await refreshService.refreshSystemGuidesForCountries(
    manifestUrl: manifestUrl,
    countries: countries,
  );
  return true;
}

Future<CompactEpgSlice> _buildAiroTvCompactEpgSnapshot({
  required String xmltvPath,
  required DateTime now,
  required List<IPTVChannel> channels,
}) async {
  final aliasesByChannel = {
    for (final channel in channels) channel.id: _xmltvGuideAliasesFor(channel),
  };
  final guideChannelIds = aliasesByChannel.values
      .expand((aliases) => aliases)
      .toSet()
      .toList(growable: false);
  final channelNamesByGuideId = {
    for (final channel in channels)
      for (final alias in aliasesByChannel[channel.id]!) alias: channel.name,
  };
  final guideRepository =
      await XmltvCompactEpgRepository.fromXmltvCurrentNextFileNative(
        path: xmltvPath,
        ingestedAt: now,
        channelIds: guideChannelIds,
        now: now,
        sourceRef: CompactEpgSourceRef.redacted('debug-tv-epg'),
        channelNamesById: channelNamesByGuideId,
      );
  final guideSlice = await guideRepository.loadCurrentNext(
    channelIds: guideChannelIds,
    now: now,
  );
  final entries = <CompactEpgEntry>[];

  for (final channel in channels) {
    for (final alias in aliasesByChannel[channel.id]!) {
      final guideEntry = guideSlice.entryForChannel(alias);
      if (guideEntry == null || !guideEntry.hasPrograms) {
        continue;
      }
      entries.add(
        CompactEpgEntry(
          channelId: channel.id,
          channelName: channel.name,
          channelNumber: channel.tvgId?.toString(),
          current: guideEntry.current,
          next: guideEntry.next,
          sourceRef: guideEntry.sourceRef,
        ),
      );
      break;
    }
  }

  return CompactEpgSlice(
    entries: entries,
    generatedAt: guideSlice.generatedAt,
    expiresAt: guideSlice.expiresAt,
    source: entries.isEmpty
        ? CompactEpgSliceSource.unavailable
        : CompactEpgSliceSource.localCache,
  );
}

List<String> _xmltvGuideAliasesFor(IPTVChannel channel) {
  final aliases = <String>{
    channel.id,
    ...channel.epgLookupIds,
    if (channel.tvgId != null) channel.tvgId.toString(),
    if (channel.tvgName != null) channel.tvgName!,
    channel.name,
    ...channel.altNames,
  };
  return aliases
      .map((alias) => alias.trim())
      .where((alias) => alias.isNotEmpty)
      .toList(growable: false);
}
