import 'package:platform_epg/platform_epg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mutable_xmltv_compact_epg_repository.dart';

Future<bool> seedAiroTvDebugDefaultPlaylist(
  SharedPreferences prefs, {
  required String playlistUrl,
  Object? parser,
}) async {
  return false;
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
  required CompactEpgRepository repository,
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
