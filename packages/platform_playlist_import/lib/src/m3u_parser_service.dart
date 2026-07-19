import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:core_data/core_data.dart';
import 'package:core_native/core_native.dart';
import 'package:dio/dio.dart';
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
  static const Duration _cacheValidity = Duration(hours: 24);

  final Dio _dio;
  final SharedPreferences _prefs;
  final KeyValueStore _store;
  final Future<Directory> Function() _cacheDirectoryProvider;
  final AiroWorkerExecutor workerExecutor;

  M3UParserService({
    required Dio dio,
    required SharedPreferences prefs,
    KeyValueStore? store,
    int maxPreferenceValueBytes = kKeyValueStorePreferenceMaxValueBytes,
    Future<Directory> Function()? cacheDirectoryProvider,
    this.workerExecutor = const AiroWorkerExecutor(),
  }) : _dio = dio,
       _prefs = prefs,
       _store =
           store ??
           PreferencesStore(prefs, maxValueBytes: maxPreferenceValueBytes),
       _cacheDirectoryProvider =
           cacheDirectoryProvider ?? getApplicationSupportDirectory;

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

  /// Perform the raw HTTP GET for [url], attaching cache validators. Shared
  /// by [_fetchAndParse] (used by [fetchPlaylist]) and
  /// [fetchPlaylistWithProgress] so both observe identical request behavior;
  /// neither the request semantics nor [fetchPlaylist]'s callers change.
  Future<Response<String>> _requestPlaylist(String url) async {
    final headers = <String, String>{'Accept-Encoding': 'gzip, deflate'};
    final etag = await _store.getString(_cacheEtagKey);
    final lastModified = await _store.getString(_cacheLastModifiedKey);
    if (etag != null && etag.isNotEmpty) {
      headers[HttpHeaders.ifNoneMatchHeader] = etag;
    }
    if (lastModified != null && lastModified.isNotEmpty) {
      headers[HttpHeaders.ifModifiedSinceHeader] = lastModified;
    }

    return _dio.get<String>(
      url,
      options: Options(
        headers: headers,
        responseType: ResponseType.plain,
        receiveTimeout: const Duration(seconds: 30),
        validateStatus: (status) =>
            status != null &&
            ((status >= HttpStatus.ok && status < HttpStatus.multipleChoices) ||
                status == HttpStatus.notModified),
      ),
    );
  }

  /// Fetch and parse M3U from URL.
  Future<_PlaylistFetchResult> _fetchAndParse(String url) async {
    final response = await _requestPlaylist(url);

    if (response.statusCode == HttpStatus.notModified) {
      final cached = await _loadFromCache(ignoreExpiry: true);
      if (cached != null && cached.isNotEmpty) {
        return _PlaylistFetchResult(channels: cached, fromCache: true);
      }
      throw Exception('Playlist not modified but no cache is available');
    }

    if (response.data == null || response.data!.isEmpty) {
      throw Exception('Empty playlist response');
    }

    final channels = await parseM3UOffMain(response.data!);
    await _saveHttpValidators(response.headers);
    return _PlaylistFetchResult(channels: channels);
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
      final response = await _requestPlaylist(playlistUrl);

      if (response.statusCode == HttpStatus.notModified) {
        final cached = await _loadFromCache(ignoreExpiry: true);
        if (cached == null || cached.isEmpty) {
          throw Exception('Playlist not modified but no cache is available');
        }
        yield* _emitCacheHitThroughReady(cached);
        return;
      }

      if (response.data == null || response.data!.isEmpty) {
        throw Exception('Empty playlist response');
      }

      yield const ImportProgress(
        stage: ImportStage.parse,
        message: 'Parsing playlist',
      );
      final channels = await parseM3UOffMain(response.data!);
      await _saveHttpValidators(response.headers);

      // parseM3UOffMain (via parseM3UChannels) already normalizes and
      // deduplicates internally, so v1 can't observe those as separate sub
      // steps; they're emitted back-to-back per the staged-import spec's
      // explicit allowance for adjacent near-zero-duration stages.
      yield ImportProgress(
        stage: ImportStage.normalize,
        fraction: 1,
        message: '${channels.length} channels parsed',
      );
      yield const ImportProgress(stage: ImportStage.deduplicate, fraction: 1);
      yield const ImportProgress(stage: ImportStage.indexing, fraction: 1);

      // Rail generation is Riverpod-driven elsewhere via railsProvider
      // invalidation; this stage is a placeholder for future real hooking.
      yield const ImportProgress(stage: ImportStage.generateRails, fraction: 1);

      await _saveToCache(channels);
      yield const ImportProgress(stage: ImportStage.persist, fraction: 1);

      yield ImportProgress(
        stage: ImportStage.ready,
        fraction: 1,
        message: 'Imported ${channels.length} channels',
      );
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
  Future<List<IPTVChannel>> parseM3UOffMain(String content) {
    return workerExecutor.run<List<IPTVChannel>>(
      debugName: 'm3u_playlist_parse',
      kind: AiroWorkerJobKind.playlistImport,
      computation: () => parseM3UChannels(content),
    );
  }

  Future<File> _cacheFile() async {
    final dir = await _cacheDirectoryProvider();
    return File('${dir.path}/$_cacheFileName');
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

/// Parse M3U content into normalized, deduplicated IPTV channels.
List<IPTVChannel> parseM3UChannels(String content) {
  final channels = <IPTVChannel>[];
  // Track seen channels by normalized name to deduplicate.
  final seenChannels = <String, IPTVChannel>{};

  for (final entry in parseM3uEntries(content)) {
    final streamUri = AiroPlaylistUrlPolicy.normalizeStreamUrl(entry.url);
    if (streamUri == null) {
      continue;
    }

    final normalizedName = _normalizeChannelName(entry.name);
    final logoUri = AiroPlaylistUrlPolicy.normalizeLogoUrl(entry.logo);

    final channel = IPTVChannel.fromM3U(
      name: _formatChannelName(entry.name),
      url: streamUri.toString(),
      logo: logoUri?.toString(),
      group: entry.group,
      tvgId: entry.tvgId,
      tvgName: entry.tvgName,
      language: entry.language,
    );

    if (!seenChannels.containsKey(normalizedName)) {
      seenChannels[normalizedName] = channel;
    } else {
      final existing = seenChannels[normalizedName]!;
      if (existing.logoUrl == null && channel.logoUrl != null) {
        seenChannels[normalizedName] = channel;
      }
    }
  }

  channels.addAll(seenChannels.values);
  return channels;
}

/// Normalize channel name for deduplication (lowercase, remove special chars).
String _normalizeChannelName(String name) {
  final buffer = StringBuffer();
  for (var i = 0; i < name.length; i++) {
    final codeUnit = name.codeUnitAt(i);

    if (codeUnit >= 0x30 && codeUnit <= 0x39) {
      buffer.writeCharCode(codeUnit);
    } else if (codeUnit >= 0x41 && codeUnit <= 0x5A) {
      buffer.writeCharCode(codeUnit + 0x20);
    } else if (codeUnit >= 0x61 && codeUnit <= 0x7A) {
      buffer.writeCharCode(codeUnit);
    }
  }
  return buffer.toString();
}

/// Format channel name for display (proper capitalization).
String _formatChannelName(String name) {
  final buffer = StringBuffer();
  var index = 0;

  while (index < name.length) {
    while (index < name.length && _isWhitespace(name.codeUnitAt(index))) {
      index++;
    }
    if (index >= name.length) break;

    final wordStart = index;
    while (index < name.length && !_isWhitespace(name.codeUnitAt(index))) {
      index++;
    }

    if (buffer.isNotEmpty) {
      buffer.write(' ');
    }

    final word = name.substring(wordStart, index);
    if (word.length <= 4 && word == word.toUpperCase()) {
      buffer.write(word);
    } else {
      buffer
        ..write(word[0].toUpperCase())
        ..write(word.substring(1).toLowerCase());
    }
  }

  return buffer.toString();
}

bool _isWhitespace(int codeUnit) {
  return codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0A ||
      codeUnit == 0x0B ||
      codeUnit == 0x0C ||
      codeUnit == 0x0D;
}
