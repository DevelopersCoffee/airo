import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/iptv_channel.dart';

/// M3U Playlist Parser with caching and fallback support
class M3UParserService {
  static const String _cacheKey = 'iptv_playlist_cache';
  static const String _cacheTimestampKey = 'iptv_playlist_timestamp';
  static const Duration _cacheValidity = Duration(hours: 24);

  final Dio _dio;
  final SharedPreferences _prefs;

  /// Primary and fallback playlist URLs
  static const List<String> _playlistUrls = [
    'https://raw.githubusercontent.com/FunctionError/PiratesTv/main/combined_playlist.m3u',
    // Add fallback URLs here
  ];

  M3UParserService({required Dio dio, required SharedPreferences prefs})
      : _dio = dio,
        _prefs = prefs;

  /// Fetch and parse playlist with caching and fallback
  Future<List<IPTVChannel>> fetchPlaylist({bool forceRefresh = false}) async {
    // Try cache first if not forcing refresh
    if (!forceRefresh) {
      final cached = await _loadFromCache();
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
    }

    // Try each playlist URL until one works
    for (final url in _playlistUrls) {
      try {
        final channels = await _fetchAndParse(url);
        if (channels.isNotEmpty) {
          await _saveToCache(channels);
          return channels;
        }
      } catch (e) {
        print('[M3U] Failed to fetch from $url: $e');
        continue;
      }
    }

    // All URLs failed, try cache as last resort
    final cached = await _loadFromCache();
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    throw Exception('Failed to load playlist from all sources');
  }

  /// Fetch and parse M3U from URL
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

    return parseM3U(response.data!);
  }

  /// Parse M3U content into channels
  List<IPTVChannel> parseM3U(String content) {
    final lines = content.split('\n');
    final channels = <IPTVChannel>[];

    String? currentName;
    String? currentLogo;
    String? currentGroup;
    String? currentTvgId;
    String? currentTvgName;
    String? currentLanguage;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.startsWith('#EXTINF:')) {
        // Parse channel info
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
        // This is the stream URL
        channels.add(IPTVChannel.fromM3U(
          name: currentName,
          url: line,
          logo: currentLogo,
          group: currentGroup,
          tvgId: currentTvgId,
          tvgName: currentTvgName,
          language: currentLanguage,
        ));

        // Reset for next channel
        currentName = null;
        currentLogo = null;
        currentGroup = null;
        currentTvgId = null;
        currentTvgName = null;
        currentLanguage = null;
      }
    }

    return channels;
  }

  /// Parse #EXTINF line attributes
  Map<String, String?> _parseExtInf(String line) {
    final result = <String, String?>{};

    // Extract name (after the comma)
    final commaIndex = line.lastIndexOf(',');
    if (commaIndex != -1) {
      result['name'] = line.substring(commaIndex + 1).trim();
    }

    // Extract attributes
    final attrPattern = RegExp(r'(\w+[-\w]*)="([^"]*)"');
    for (final match in attrPattern.allMatches(line)) {
      result[match.group(1)!] = match.group(2);
    }

    return result;
  }

  /// Load channels from cache
  Future<List<IPTVChannel>?> _loadFromCache() async {
    final timestamp = _prefs.getInt(_cacheTimestampKey);
    if (timestamp == null) return null;

    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (DateTime.now().difference(cacheTime) > _cacheValidity) {
      return null; // Cache expired
    }

    final cached = _prefs.getString(_cacheKey);
    if (cached == null) return null;

    return parseM3U(cached);
  }

  /// Save channels to cache
  Future<void> _saveToCache(List<IPTVChannel> channels) async {
    // Store as simplified M3U format for easy re-parsing
    final buffer = StringBuffer('#EXTM3U\n');
    for (final ch in channels) {
      buffer.writeln(
          '#EXTINF:-1 tvg-logo="${ch.logoUrl ?? ""}" group-title="${ch.group}",${ch.name}');
      buffer.writeln(ch.streamUrl);
    }
    await _prefs.setString(_cacheKey, buffer.toString());
    await _prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Clear cache
  Future<void> clearCache() async {
    await _prefs.remove(_cacheKey);
    await _prefs.remove(_cacheTimestampKey);
  }
}

