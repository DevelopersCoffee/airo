import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:core_data/core_data.dart';
import 'package:core_native/core_native.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_worker_jobs/platform_worker_jobs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// M3U playlist parser for user-supplied sources.
class M3UParserService {
  static const String _playlistUrlKey = 'iptv_user_playlist_url';
  static const String _legacyCacheKey = 'iptv_playlist_cache';
  static const String _cacheTimestampKey = 'iptv_playlist_timestamp';
  static const String _cacheEtagKey = 'iptv_playlist_etag';
  static const String _cacheLastModifiedKey = 'iptv_playlist_last_modified';
  static const String _cacheFileName = 'iptv_channel_cache.json';
  static const String _downloadDirectoryName = 'playlist_downloads';
  static const Duration _cacheValidity = Duration(hours: 24);

  final Dio _dio;
  final SharedPreferences _prefs;
  final KeyValueStore _store;
  final Future<Directory> Function() _cacheDirectoryProvider;
  final Future<Directory> Function() _downloadDirectoryProvider;
  final AiroWorkerExecutor workerExecutor;

  M3UParserService({
    required Dio dio,
    required SharedPreferences prefs,
    KeyValueStore? store,
    int maxPreferenceValueBytes = kKeyValueStorePreferenceMaxValueBytes,
    Future<Directory> Function()? cacheDirectoryProvider,
    Future<Directory> Function()? downloadDirectoryProvider,
    this.workerExecutor = const AiroWorkerExecutor(),
    // Keep the public constructor API as `dio`/`prefs` instead of exposing
    // private field names to callers.
    // ignore: prefer_initializing_formals
  }) : _dio = dio,
       _prefs = prefs,
       _store =
           store ??
           PreferencesStore(prefs, maxValueBytes: maxPreferenceValueBytes),
       _cacheDirectoryProvider =
           cacheDirectoryProvider ?? getApplicationSupportDirectory,
       _downloadDirectoryProvider =
           downloadDirectoryProvider ?? getTemporaryDirectory;

  /// Fetch and parse the user-supplied playlist with caching.
  Future<List<IPTVChannel>> fetchPlaylist({bool forceRefresh = false}) async {
    final playlistUrl = getPlaylistUrl();
    if (playlistUrl == null) {
      return const [];
    }

    if (!forceRefresh) {
      final cached = await _loadFromCache();
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
    }

    try {
      final result = await _fetchAndParse(playlistUrl);
      if (result.channels.isNotEmpty) {
        if (!result.fromCache) {
          await _saveToCache(result.channels);
        }
        return result.channels;
      }
    } catch (_) {
      developer.log(
        'Failed to fetch user playlist.',
        name: 'platform_playlist_import',
      );
    }

    final cached = await _loadFromCache();
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    return const [];
  }

  /// Return the configured user playlist URL, if any.
  String? getPlaylistUrl() {
    final value = _prefs.getString(_playlistUrlKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// Persist a user-supplied playlist URL.
  Future<void> setPlaylistUrl(String url) async {
    final normalized = url.trim();
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw ArgumentError.value(
        url,
        'url',
        'Enter a valid HTTP(S) playlist URL.',
      );
    }

    await _store.setString(_playlistUrlKey, normalized);
    await clearCache();
  }

  /// Remove the configured playlist and its user-derived cache.
  Future<void> clearPlaylist() async {
    await _store.remove(_playlistUrlKey);
    await clearCache();
  }

  /// Build the HTTP options for playlist requests, attaching cache validators.
  /// Shared by [_fetchAndParse] (used by [fetchPlaylist]) and
  /// [fetchPlaylistWithProgress] so both observe identical request behavior;
  /// neither the request semantics nor [fetchPlaylist]'s callers change.
  Future<Options> _playlistRequestOptions() async {
    final headers = <String, String>{'Accept-Encoding': 'gzip, deflate'};
    final etag = await _store.getString(_cacheEtagKey);
    final lastModified = await _store.getString(_cacheLastModifiedKey);
    if (etag != null && etag.isNotEmpty) {
      headers[HttpHeaders.ifNoneMatchHeader] = etag;
    }
    if (lastModified != null && lastModified.isNotEmpty) {
      headers[HttpHeaders.ifModifiedSinceHeader] = lastModified;
    }

    return Options(
      headers: headers,
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (status) =>
          status != null &&
          ((status >= HttpStatus.ok && status < HttpStatus.multipleChoices) ||
              status == HttpStatus.notModified),
    );
  }

  /// Download the playlist to a temporary file so native imports can parse
  /// from disk instead of materializing the HTTP body as a Dart string first.
  Future<_PlaylistDownloadResult> _downloadPlaylist(String url) async {
    final file = await _newPlaylistDownloadFile();
    final response = await _dio.download(
      url,
      file.path,
      options: await _playlistRequestOptions(),
    );
    return _PlaylistDownloadResult(response: response, file: file);
  }

  /// Fetch and parse M3U from URL.
  Future<_PlaylistFetchResult> _fetchAndParse(String url) async {
    final download = await _downloadPlaylist(url);
    final response = download.response;

    try {
      if (response.statusCode == HttpStatus.notModified) {
        final cached = await _loadFromCache(ignoreExpiry: true);
        if (cached != null && cached.isNotEmpty) {
          return _PlaylistFetchResult(channels: cached, fromCache: true);
        }
        throw Exception('Playlist not modified but no cache is available');
      }

      if (!await download.file.exists() || await download.file.length() == 0) {
        throw Exception('Empty playlist response');
      }

      final parseResult = await parseM3UFileWithStatsOffMain(
        download.file.path,
      );
      await _saveHttpValidators(response.headers);
      return _PlaylistFetchResult(channels: parseResult.channels);
    } finally {
      await _deletePlaylistDownload(download.file);
    }
  }

  /// Stream-based staged import of the user-supplied playlist, wrapping this
  /// service's real cache/HTTP/parse flow with one [ImportProgress] per
  /// [ImportStage] transition so long-running imports can be surfaced in the
  /// UI (spec §4.4). Terminal emission is either `ImportStage.ready` (channel
  /// count in [ImportProgress.message]) or `ImportStage.failed` (non-null
  /// [ImportProgress.error], `ready` never emitted). Does not change
  /// [fetchPlaylist]'s behavior or its existing callers.
  Stream<ImportProgress> fetchPlaylistWithProgress({
    bool forceRefresh = false,
  }) async* {
    yield const ImportProgress(
      stage: ImportStage.import_,
      message: 'Starting playlist import',
    );

    final playlistUrl = getPlaylistUrl();
    if (playlistUrl == null) {
      yield ImportProgress(
        stage: ImportStage.failed,
        error: StateError('No user playlist URL is configured.'),
      );
      return;
    }
    yield const ImportProgress(
      stage: ImportStage.validate,
      fraction: 1,
      message: 'Playlist URL validated',
    );

    try {
      if (!forceRefresh) {
        final cached = await _loadFromCache();
        if (cached != null && cached.isNotEmpty) {
          yield* _emitCacheHitThroughReady(cached);
          return;
        }
      }

      yield const ImportProgress(
        stage: ImportStage.download,
        message: 'Downloading playlist',
      );
      final download = await _downloadPlaylist(playlistUrl);
      final response = download.response;

      try {
        if (response.statusCode == HttpStatus.notModified) {
          final cached = await _loadFromCache(ignoreExpiry: true);
          if (cached == null || cached.isEmpty) {
            throw Exception('Playlist not modified but no cache is available');
          }
          yield* _emitCacheHitThroughReady(cached);
          return;
        }

        if (!await download.file.exists() ||
            await download.file.length() == 0) {
          throw Exception('Empty playlist response');
        }

        yield const ImportProgress(
          stage: ImportStage.parse,
          message: 'Parsing playlist',
        );
        final parseResult = await parseM3UFileWithStatsOffMain(
          download.file.path,
        );
        final channels = parseResult.channels;
        await _saveHttpValidators(response.headers);

        // parseM3UOffMain (via parseM3UChannels) already normalizes and
        // deduplicates internally, so v1 can't observe those as separate sub
        // steps; they're emitted back-to-back per the staged-import spec's
        // explicit allowance for adjacent near-zero-duration stages.
        yield ImportProgress(
          stage: ImportStage.normalize,
          fraction: 1,
          message:
              '${parseResult.stats.parsedCount} parsed; '
              '${parseResult.stats.skippedCount} skipped; '
              '${parseResult.stats.malformedCount} malformed',
        );
        yield const ImportProgress(stage: ImportStage.deduplicate, fraction: 1);
        yield const ImportProgress(stage: ImportStage.indexing, fraction: 1);

        // Rail generation is Riverpod-driven elsewhere via railsProvider
        // invalidation; this stage is a placeholder for future real hooking.
        yield const ImportProgress(
          stage: ImportStage.generateRails,
          fraction: 1,
        );

        await _saveToCache(channels);
        yield const ImportProgress(stage: ImportStage.persist, fraction: 1);

        yield ImportProgress(
          stage: ImportStage.ready,
          fraction: 1,
          message: 'Imported ${channels.length} channels',
        );
      } finally {
        await _deletePlaylistDownload(download.file);
      }
    } catch (error) {
      yield ImportProgress(stage: ImportStage.failed, error: error);
    }
  }

  /// Emit the collapsed download→parse→normalize→deduplicate→indexing stages
  /// as one fast pass for a cache hit, then generateRails/persist/ready.
  /// Real parsing already happened on a prior import, so v1 collapses these
  /// per the staged-import spec's near-zero-duration allowance.
  Stream<ImportProgress> _emitCacheHitThroughReady(
    List<IPTVChannel> channels,
  ) async* {
    yield ImportProgress(
      stage: ImportStage.indexing,
      fraction: 1,
      message: '${channels.length} channels loaded from cache',
    );
    yield const ImportProgress(stage: ImportStage.generateRails, fraction: 1);
    yield const ImportProgress(stage: ImportStage.persist, fraction: 1);
    yield ImportProgress(
      stage: ImportStage.ready,
      fraction: 1,
      message: 'Imported ${channels.length} channels',
    );
  }

  /// Parse M3U content into channels with deduplication.
  List<IPTVChannel> parseM3U(String content) => parseM3UChannels(content);

  /// Parse M3U content in the platform worker boundary used by async flows.
  ///
  /// On native platforms this parses in the Rust core via flutter_rust_bridge:
  /// the FFI call dispatches to Rust worker threads, so the Dart UI isolate is
  /// never blocked (and `RustLib` per-isolate statics cannot be reused inside
  /// a spawned `Isolate.run`, so the worker boundary cannot host FFI calls).
  /// The Dart fallback parser behind the worker executor remains the web path
  /// per the repo isolate policy; `parseM3uChannelsWithStatsNative` also falls
  /// back to it automatically when the native bridge is unavailable.
  Future<List<IPTVChannel>> parseM3UOffMain(String content) {
    return parseM3UWithStatsOffMain(content).then((result) => result.channels);
  }

  /// Parse through the production worker boundary and retain aggregate-only
  /// telemetry for progress/diagnostics. No source URL or playlist entry is
  /// retained in the stats result.
  Future<M3UParseResult> parseM3UWithStatsOffMain(String content) async {
    if (!kIsWeb) {
      final result = await parseM3uChannelsWithStatsNative(content);
      return M3UParseResult(
        channels: _channelsFromNativeM3uChannels(result.channels),
        stats: M3UParseStats(
          parsedCount: result.stats.parsedCount,
          skippedCount: result.stats.skippedCount,
          malformedCount: result.stats.malformedCount,
          elapsedMillis: result.stats.elapsedMillis,
        ),
      );
    }
    return workerExecutor.run<M3UParseResult>(
      debugName: 'm3u_playlist_parse',
      kind: AiroWorkerJobKind.playlistImport,
      computation: () {
        final result = parseM3uChannelsWithStats(content);
        return M3UParseResult(
          channels: _channelsFromNativeM3uChannels(result.channels),
          stats: M3UParseStats(
            parsedCount: result.stats.parsedCount,
            skippedCount: result.stats.skippedCount,
            malformedCount: result.stats.malformedCount,
            elapsedMillis: result.stats.elapsedMillis,
          ),
        );
      },
    );
  }

  /// Parse an already-downloaded M3U file through the production native path.
  ///
  /// Native platforms parse from the file in Rust so the HTTP body does not
  /// need to become a Dart `String` first. The web/test fallback preserves
  /// deterministic behavior when the native library is unavailable.
  Future<M3UParseResult> parseM3UFileWithStatsOffMain(String path) async {
    if (!kIsWeb) {
      final result = await parseM3uFileChannelsWithStatsNative(path);
      return M3UParseResult(
        channels: _channelsFromNativeM3uChannels(result.channels),
        stats: M3UParseStats(
          parsedCount: result.stats.parsedCount,
          skippedCount: result.stats.skippedCount,
          malformedCount: result.stats.malformedCount,
          elapsedMillis: result.stats.elapsedMillis,
        ),
      );
    }
    return workerExecutor.run<M3UParseResult>(
      debugName: 'm3u_playlist_file_parse',
      kind: AiroWorkerJobKind.playlistImport,
      computation: () {
        final result = parseM3uChannelsWithStats(File(path).readAsStringSync());
        return M3UParseResult(
          channels: _channelsFromNativeM3uChannels(result.channels),
          stats: M3UParseStats(
            parsedCount: result.stats.parsedCount,
            skippedCount: result.stats.skippedCount,
            malformedCount: result.stats.malformedCount,
            elapsedMillis: result.stats.elapsedMillis,
          ),
        );
      },
    );
  }

  Future<File> _cacheFile() async {
    final dir = await _cacheDirectoryProvider();
    return File('${dir.path}/$_cacheFileName');
  }

  Future<File> _newPlaylistDownloadFile() async {
    final root = await _downloadDirectoryProvider();
    final dir = Directory('${root.path}/$_downloadDirectoryName');
    await dir.create(recursive: true);
    return File(
      '${dir.path}/playlist_${DateTime.now().microsecondsSinceEpoch}.m3u',
    );
  }

  Future<void> _deletePlaylistDownload(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Temporary playlist cleanup is best-effort; no cache metadata points
      // at this raw download file.
    }
  }

  /// Load channels from structured cache without reparsing the M3U payload.
  Future<List<IPTVChannel>?> _loadFromCache({bool ignoreExpiry = false}) async {
    await _store.remove(_legacyCacheKey);

    final timestamp = await _store.getInt(_cacheTimestampKey);
    if (timestamp == null) return null;

    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (!ignoreExpiry &&
        DateTime.now().difference(cacheTime) > _cacheValidity) {
      return null;
    }

    try {
      final file = await _cacheFile();
      if (!file.existsSync()) return null;

      return workerExecutor.run<List<IPTVChannel>>(
        debugName: 'm3u_playlist_cache_decode',
        kind: AiroWorkerJobKind.playlistImport,
        computation: () => _readChannelCacheFile(file.path),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Channel cache read failed.',
        name: 'platform_playlist_import',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Save channels to structured cache and remove the legacy M3U prefs value.
  Future<void> _saveToCache(List<IPTVChannel> channels) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final file = await _cacheFile();
      await file.parent.create(recursive: true);
      final payload = await workerExecutor.run<String>(
        debugName: 'm3u_playlist_cache_encode',
        kind: AiroWorkerJobKind.playlistImport,
        computation: () => _encodeChannelCache(channels),
      );
      await file.writeAsString(payload);
      await _store.setInt(_cacheTimestampKey, now);
      await _store.remove(_legacyCacheKey);
    } catch (error, stackTrace) {
      developer.log(
        'Channel cache write failed.',
        name: 'platform_playlist_import',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Clear cache.
  Future<void> clearCache() async {
    await _store.remove(_legacyCacheKey);
    await _store.remove(_cacheTimestampKey);
    await _store.remove(_cacheEtagKey);
    await _store.remove(_cacheLastModifiedKey);

    try {
      final file = await _cacheFile();
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {
      // Cache deletion is best-effort; stale metadata was already removed.
    }
  }

  Future<void> _saveHttpValidators(Headers headers) async {
    await _setOrRemove(_cacheEtagKey, headers.value(HttpHeaders.etagHeader));
    await _setOrRemove(
      _cacheLastModifiedKey,
      headers.value(HttpHeaders.lastModifiedHeader),
    );
  }

  Future<void> _setOrRemove(String key, String? value) async {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      await _store.remove(key);
      return;
    }
    try {
      await _store.setString(key, normalized);
    } on KeyValueStoreValueTooLargeException catch (error, stackTrace) {
      await _store.remove(key);
      developer.log(
        'Playlist HTTP validator exceeded preference tier and was dropped.',
        name: 'platform_playlist_import',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

class _PlaylistFetchResult {
  const _PlaylistFetchResult({required this.channels, this.fromCache = false});

  final List<IPTVChannel> channels;
  final bool fromCache;
}

class _PlaylistDownloadResult {
  const _PlaylistDownloadResult({required this.response, required this.file});

  final Response<dynamic> response;
  final File file;
}

/// Aggregate-only output of a playlist parse. Channel records remain local to
/// the import pipeline while progress and diagnostics use only [stats].
class M3UParseResult {
  const M3UParseResult({required this.channels, required this.stats});

  final List<IPTVChannel> channels;
  final M3UParseStats stats;
}

class M3UParseStats {
  const M3UParseStats({
    required this.parsedCount,
    required this.skippedCount,
    required this.malformedCount,
    required this.elapsedMillis,
  });

  final int parsedCount;
  final int skippedCount;
  final int malformedCount;
  final int elapsedMillis;
}

String _encodeChannelCache(List<IPTVChannel> channels) {
  return jsonEncode({
    'channels': channels.map((channel) => channel.toJson()).toList(),
  });
}

Future<List<IPTVChannel>> _readChannelCacheFile(String path) async {
  final raw = await File(path).readAsString();
  final payload = jsonDecode(raw) as Map<String, dynamic>;
  final channels = payload['channels'] as List<dynamic>? ?? const [];
  return channels
      .map((channel) => IPTVChannel.fromJson(channel as Map<String, dynamic>))
      .toList();
}

/// Parse M3U content into normalized, deduplicated IPTV channels using the
/// synchronous Dart fallback parser from core_native. Kept for deterministic
/// tests and the web fallback; native production paths use
/// [parseM3UChannelsNative].
List<IPTVChannel> parseM3UChannels(String content) =>
    _channelsFromNativeM3uChannels(parseM3uChannelsWithStats(content).channels);

/// Parse M3U content through the single Rust core parser, falling back to the
/// Dart parser when the native bridge is unavailable (e.g. host-only test
/// runs without the compiled library).
Future<List<IPTVChannel>> parseM3UChannelsNative(String content) async {
  final result = await parseM3uChannelsWithStatsNative(content);
  return _channelsFromNativeM3uChannels(result.channels);
}

List<IPTVChannel> _channelsFromNativeM3uChannels(
  Iterable<NativeM3uChannel> channels,
) {
  return channels
      .map(
        (channel) => IPTVChannel.fromM3U(
          name: channel.name,
          url: channel.url,
          logo: channel.logo,
          group: channel.group,
          tvgId: channel.tvgId,
          tvgName: channel.tvgName,
          language: channel.language,
        ),
      )
      .toList(growable: false);
}
