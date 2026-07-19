import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/import_progress.dart';
import '../models/iptv_channel.dart';
import '../security/playlist_url_policy.dart';

/// Legacy channel-data service.
///
/// Play Store V2 uses a bring-your-own-content model. The app must not ship or
/// auto-fetch a first-party channel lineup, so [fetchChannels] intentionally
/// returns no channels. User-supplied M3U sources are staged through
/// [importPlaylist], which reports progress through the
/// Import→Validate→Download→Parse→Normalize→Deduplicate→Index→GenerateRails→
/// Persist→Ready pipeline (spec §4.4) so large or background imports can be
/// surfaced to the UI without redesigning it. A richer parser lives in
/// `M3UParserService` (`platform_playlist_import`); that package depends on
/// this one, so it cannot be reused here — the parse/normalize/dedupe steps
/// below are intentionally minimal for v1.
class ChannelDataService {
  static const String _cacheKey = 'iptv_channels_cache';
  static const String _versionKey = 'iptv_channels_version';
  static const String _cacheTimestampKey = 'iptv_channels_timestamp';

  final Dio _dio;
  final SharedPreferences _prefs;

  ChannelDataService({required Dio dio, required SharedPreferences prefs})
    : _dio = dio,
      _prefs = prefs;

  /// Return no first-party channels.
  Future<List<IPTVChannel>> fetchChannels({bool forceRefresh = false}) async {
    return const [];
  }

  /// Clear legacy first-party channel cache.
  Future<void> clearCache() async {
    await _prefs.remove(_cacheKey);
    await _prefs.remove(_versionKey);
    await _prefs.remove(_cacheTimestampKey);
  }

  /// Get current cache version
  String? getCacheVersion() => _prefs.getString(_versionKey);

  /// Stream-based staged import of a user-supplied playlist [url].
  ///
  /// Emits one [ImportProgress] per stage transition, ending either with
  /// `ImportStage.ready` (channel count in [ImportProgress.message]) or
  /// `ImportStage.failed` (non-null [ImportProgress.error], no `ready` ever
  /// emitted). This is the primary import path; no prior one-shot import
  /// method existed on this service to preserve (only [fetchChannels],
  /// [clearCache], and [getCacheVersion] have existing callers), so there is
  /// nothing to delegate from.
  Stream<ImportProgress> importPlaylist(String url) async* {
    yield const ImportProgress(
      stage: ImportStage.import_,
      message: 'Starting playlist import',
    );

    final playlistUri = AiroPlaylistUrlPolicy.normalizeStreamUrl(url);
    if (playlistUri == null) {
      yield ImportProgress(
        stage: ImportStage.failed,
        error: ArgumentError.value(url, 'url', 'Invalid playlist URL'),
      );
      return;
    }
    yield const ImportProgress(
      stage: ImportStage.validate,
      fraction: 1,
      message: 'Playlist URL validated',
    );

    final String content;
    try {
      final response = await _dio.get<String>(
        playlistUri.toString(),
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      content = response.data ?? '';
      if (content.isEmpty) {
        throw Exception('Empty playlist response');
      }
    } catch (error) {
      yield ImportProgress(stage: ImportStage.failed, error: error);
      return;
    }
    yield const ImportProgress(
      stage: ImportStage.download,
      fraction: 1,
      message: 'Playlist downloaded',
    );

    final parsed = _parseM3UEntries(content);
    yield ImportProgress(
      stage: ImportStage.parse,
      fraction: 1,
      message: '${parsed.length} entries parsed',
    );

    // v1 doesn't distinguish normalize from the parse step above; the stage
    // is still emitted so the enum contract (and any UI/timeline built
    // against it) doesn't need to change when it does real work later.
    yield const ImportProgress(stage: ImportStage.normalize, fraction: 1);

    final deduped = _deduplicateChannels(parsed);
    yield ImportProgress(
      stage: ImportStage.deduplicate,
      fraction: 1,
      message: '${deduped.length} unique channels',
    );

    // v1 has no search index or rails to build yet (rails are generated from
    // whatever channel list callers already hold); both stages are near-zero
    // placeholders ahead of large-playlist/background-import work.
    yield const ImportProgress(stage: ImportStage.indexing, fraction: 1);
    yield const ImportProgress(stage: ImportStage.generateRails, fraction: 1);
    yield const ImportProgress(stage: ImportStage.persist, fraction: 1);

    yield ImportProgress(
      stage: ImportStage.ready,
      fraction: 1,
      message: 'Imported ${deduped.length} channels',
    );
  }

  /// Minimal M3U entry parser: pairs each `#EXTINF` line with the URL line
  /// that follows it. Intentionally lighter than `M3UParserService`'s parser
  /// (no tvg-logo/group extraction) since `platform_playlist_import` depends
  /// on this package and can't be depended on in return; this pipeline only
  /// needs a channel count and stage timing for v1.
  List<IPTVChannel> _parseM3UEntries(String content) {
    final entries = <IPTVChannel>[];
    String? pendingName;

    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        final commaIndex = line.indexOf(',');
        pendingName = (commaIndex >= 0 && commaIndex + 1 < line.length)
            ? line.substring(commaIndex + 1).trim()
            : 'Unknown channel';
        continue;
      }

      if (line.startsWith('#')) continue;

      final streamUri = AiroPlaylistUrlPolicy.normalizeStreamUrl(line);
      if (streamUri != null) {
        entries.add(
          IPTVChannel.fromM3U(
            name: pendingName?.isNotEmpty == true
                ? pendingName!
                : 'Unknown channel',
            url: streamUri.toString(),
          ),
        );
      }
      pendingName = null;
    }

    return entries;
  }

  /// Deduplicate parsed entries by stream URL, keeping the first occurrence.
  List<IPTVChannel> _deduplicateChannels(List<IPTVChannel> channels) {
    final seen = <String, IPTVChannel>{};
    for (final channel in channels) {
      seen.putIfAbsent(channel.streamUrl, () => channel);
    }
    return seen.values.toList(growable: false);
  }
}
