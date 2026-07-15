import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:core_workers/core_workers.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:platform_channels/platform_channels.dart';

/// M3U playlist parser for user-supplied sources.
class M3UParserService {
  static const String _playlistUrlKey = 'iptv_user_playlist_url';

  // Legacy prefs keys — kept only for migration (removal on first load).
  static const String _legacyCacheKey = 'iptv_playlist_cache';
  static const String _cacheTimestampKey = 'iptv_playlist_timestamp';

  static const String _cacheFileName = 'iptv_channel_cache.json';
  static const Duration _cacheValidity = Duration(hours: 24);

  final Dio _dio;
  final SharedPreferences _prefs;

  M3UParserService({required this._dio, required this._prefs});

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
      final channels = await _fetchAndParse(playlistUrl);
      if (channels.isNotEmpty) {
        await _saveToCache(channels);
        return channels;
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

  /// Fetch and parse M3U from URL. Parsing runs on a worker isolate.
  Future<List<IPTVChannel>> _fetchAndParse(String url) async {
    final response = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    if (response.data == null || response.data!.isEmpty) {
      throw Exception('Empty playlist response');
    }

    final content = response.data!;
    return runOffMain(() => parseM3U(content));
  }

  /// Parse M3U content into channels with deduplication
  List<IPTVChannel> parseM3U(String content) {
    final lines = content.split('\n');
    final channels = <IPTVChannel>[];
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
        final normalizedName = _normalizeChannelName(currentName);

        final channel = IPTVChannel.fromM3U(
          name: _formatChannelName(currentName),
          url: line,
          logo: currentLogo,
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

  /// Normalize channel name for deduplication (lowercase, remove special chars)
  String _normalizeChannelName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .replaceAll(RegExp(r'\s+'), '');
  }

  /// Format channel name for display (proper capitalization)
  String _formatChannelName(String name) {
    name = name.trim().replaceAll(RegExp(r'\s+'), ' ');

    return name
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          if (word.length <= 4 && word == word.toUpperCase()) {
            return word;
          }
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  /// Parse #EXTINF line attributes
  Map<String, String?> _parseExtInf(String line) {
    final result = <String, String?>{};

    final commaIndex = line.lastIndexOf(',');
    if (commaIndex != -1) {
      result['name'] = line.substring(commaIndex + 1).trim();
    }

    final attrPattern = RegExp(r'(\w+[-\w]*)="([^"]*)"');
    for (final match in attrPattern.allMatches(line)) {
      result[match.group(1)!] = match.group(2);
    }

    return result;
  }

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_cacheFileName');
  }

  /// Load channels from JSON file cache. Migrates legacy prefs M3U string.
  Future<List<IPTVChannel>?> _loadFromCache() async {
    // One-time migration: remove multi-MB M3U string from SharedPreferences.
    if (_prefs.containsKey(_legacyCacheKey)) {
      unawaited(_prefs.remove(_legacyCacheKey));
    }

    // Quick validity check via prefs timestamp before opening the file.
    final timestamp = _prefs.getInt(_cacheTimestampKey);
    if (timestamp == null) return null;

    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (DateTime.now().difference(cacheTime) > _cacheValidity) {
      return null;
    }

    try {
      final file = await _cacheFile();
      if (!file.existsSync()) return null;

      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (json['channels'] as List<dynamic>)
          .map((c) => IPTVChannel.fromJson(c as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log(
        'Channel cache read failed: $e',
        name: 'platform_playlist_import',
      );
      return null;
    }
  }

  /// Save channels to JSON file cache; remove legacy M3U string from prefs.
  Future<void> _saveToCache(List<IPTVChannel> channels) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final file = await _cacheFile();
      await file.writeAsString(
        jsonEncode({'timestamp': now, 'channels': channels.map((c) => c.toJson()).toList()}),
      );
      await _prefs.setInt(_cacheTimestampKey, now);
      await _prefs.remove(_legacyCacheKey);
    } catch (e) {
      developer.log(
        'Channel cache write failed: $e',
        name: 'platform_playlist_import',
      );
    }
  }

  /// Clear cache (file + prefs timestamp).
  Future<void> clearCache() async {
    await _prefs.remove(_legacyCacheKey);
    await _prefs.remove(_cacheTimestampKey);
    try {
      final file = await _cacheFile();
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }
}

// Suppress lint for fire-and-forget unawaited calls.
void unawaited(Future<void> future) {}
