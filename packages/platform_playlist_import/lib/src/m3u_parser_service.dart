import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

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
  static final RegExp _extInfAttributePattern = RegExp(
    r'(\w+[-\w]*)="([^"]*)"',
  );

  final Dio _dio;
  final SharedPreferences _prefs;
  final Future<Directory> Function() _cacheDirectoryProvider;
  final AiroWorkerExecutor workerExecutor;

  M3UParserService({
    required Dio dio,
    required SharedPreferences prefs,
    Future<Directory> Function()? cacheDirectoryProvider,
    this.workerExecutor = const AiroWorkerExecutor(),
  }) : _dio = dio,
       _prefs = prefs,
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

    await _prefs.setString(_playlistUrlKey, normalized);
    await clearCache();
  }

  /// Remove the configured playlist and its user-derived cache.
  Future<void> clearPlaylist() async {
    await _prefs.remove(_playlistUrlKey);
    await clearCache();
  }

  /// Fetch and parse M3U from URL.
  Future<_PlaylistFetchResult> _fetchAndParse(String url) async {
    final headers = <String, String>{'Accept-Encoding': 'gzip, deflate'};
    final etag = _prefs.getString(_cacheEtagKey);
    final lastModified = _prefs.getString(_cacheLastModifiedKey);
    if (etag != null && etag.isNotEmpty) {
      headers[HttpHeaders.ifNoneMatchHeader] = etag;
    }
    if (lastModified != null && lastModified.isNotEmpty) {
      headers[HttpHeaders.ifModifiedSinceHeader] = lastModified;
    }

    final response = await _dio.get<String>(
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

  /// Parse M3U content into channels with deduplication.
  List<IPTVChannel> parseM3U(String content) => _parseM3UContent(content);

  /// Parse M3U content in the platform worker boundary used by async flows.
  Future<List<IPTVChannel>> parseM3UOffMain(String content) {
    return workerExecutor.run<List<IPTVChannel>>(
      debugName: 'm3u_playlist_parse',
      kind: AiroWorkerJobKind.playlistImport,
      computation: () => _parseM3UContent(content),
    );
  }

  Future<File> _cacheFile() async {
    final dir = await _cacheDirectoryProvider();
    return File('${dir.path}/$_cacheFileName');
  }

  /// Load channels from structured cache without reparsing the M3U payload.
  Future<List<IPTVChannel>?> _loadFromCache({bool ignoreExpiry = false}) async {
    await _prefs.remove(_legacyCacheKey);

    final timestamp = _prefs.getInt(_cacheTimestampKey);
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
      await _prefs.setInt(_cacheTimestampKey, now);
      await _prefs.remove(_legacyCacheKey);
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
    await _prefs.remove(_legacyCacheKey);
    await _prefs.remove(_cacheTimestampKey);
    await _prefs.remove(_cacheEtagKey);
    await _prefs.remove(_cacheLastModifiedKey);

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
      await _prefs.remove(key);
      return;
    }
    await _prefs.setString(key, normalized);
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

List<IPTVChannel> _parseM3UContent(String content) {
  final lines = content.split('\n');
  final channels = <IPTVChannel>[];
  // Track seen channels by normalized name to deduplicate.
  final seenChannels = <String, IPTVChannel>{};

  String? currentName;
  String? currentLogo;
  String? currentGroup;
  String? currentTvgId;
  String? currentTvgName;
  String? currentLanguage;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();

    if (line.startsWith('#EXTINF:')) {
      final info = _parseExtInf(line);
      currentName = info['name'];
      currentLogo = info['tvg-logo'];
      currentGroup = info['group-title'];
      currentTvgId = info['tvg-id'];
      currentTvgName = info['tvg-name'];
      currentLanguage = info['tvg-language'];
    } else if (line.isNotEmpty &&
        !line.startsWith('#') &&
        currentName != null) {
      final streamUri = AiroPlaylistUrlPolicy.normalizeStreamUrl(line);
      if (streamUri == null) {
        currentName = null;
        currentLogo = null;
        currentGroup = null;
        currentTvgId = null;
        currentTvgName = null;
        currentLanguage = null;
        continue;
      }

      final normalizedName = _normalizeChannelName(currentName);
      final logoUri = AiroPlaylistUrlPolicy.normalizeLogoUrl(currentLogo);

      final channel = IPTVChannel.fromM3U(
        name: _formatChannelName(currentName),
        url: streamUri.toString(),
        logo: logoUri?.toString(),
        group: currentGroup,
        tvgId: currentTvgId,
        tvgName: currentTvgName,
        language: currentLanguage,
      );

      if (!seenChannels.containsKey(normalizedName)) {
        seenChannels[normalizedName] = channel;
      } else {
        final existing = seenChannels[normalizedName]!;
        if (existing.logoUrl == null && channel.logoUrl != null) {
          seenChannels[normalizedName] = channel;
        }
      }

      currentName = null;
      currentLogo = null;
      currentGroup = null;
      currentTvgId = null;
      currentTvgName = null;
      currentLanguage = null;
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

/// Parse #EXTINF line attributes.
Map<String, String?> _parseExtInf(String line) {
  final result = <String, String?>{};

  final commaIndex = line.lastIndexOf(',');
  if (commaIndex != -1) {
    result['name'] = line.substring(commaIndex + 1).trim();
  }

  for (final match in M3UParserService._extInfAttributePattern.allMatches(
    line,
  )) {
    result[match.group(1)!] = match.group(2);
  }

  return result;
}
