import 'package:platform_epg/platform_epg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mutable_xmltv_compact_epg_repository.dart';

const _legacyPlaylistUrlKey = 'iptv_user_playlist_url';

Future<bool> seedAiroTvDebugDefaultPlaylist(
  SharedPreferences prefs, {
  required String playlistUrl,
  Object? parser,
}) async {
  final normalizedUrl = playlistUrl.trim();
  if (normalizedUrl.isEmpty) return false;

  final existingUrl = prefs.getString(_legacyPlaylistUrlKey)?.trim();
  if (existingUrl != null && existingUrl.isNotEmpty) return false;

  await prefs.setString(_legacyPlaylistUrlKey, normalizedUrl);
  return true;
}

Future<void> warmAiroTvDebugDefaultPlaylistCache(
  SharedPreferences prefs, {
  required String playlistUrl,
  Object? parser,
}) async {}

SnapshotBackedCompactEpgRepository createAiroTvCompactEpgRepository({
  Object? supportDirectoryProvider,
  CompactEpgRepository? fallback,
}) {
  return SnapshotBackedCompactEpgRepository(
    store: InMemoryCompactEpgSnapshotStore(),
    fallback: fallback ?? const EmptyCompactEpgRepository(),
  );
}

Future<Duration?> warmAiroTvDebugDefaultEpgCache(
  SharedPreferences prefs, {
  required SnapshotBackedCompactEpgRepository repository,
  MutableXmltvCompactEpgRepository? windowRepository,
  required String epgUrl,
  Object? parser,
  Object? dio,
  Object? epgDownloadDirectoryProvider,
  Object? clock,
  Object? workerExecutor,
}) async {
  return null;
}

Future<void> refreshAiroTvConfiguredXmltvSource(
  SharedPreferences prefs, {
  required MutableXmltvCompactEpgRepository repository,
  Object? dio,
  Object? sourceStore,
  Object? downloadDirectoryProvider,
}) async {}

Future<bool> refreshAiroTvBundledSystemGuide(
  SharedPreferences prefs, {
  required MutableXmltvCompactEpgRepository repository,
  required String bundledPlaylistUrl,
  required String manifestUrl,
  required String country,
  Object? parser,
  Object? dio,
  Object? sourceStore,
  Object? downloadDirectoryProvider,
}) async {
  return false;
}
