import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:platform_channels/platform_channels.dart';

/// M3U playlist parser for user-supplied sources.
class M3UParserService {
  static const String _playlistUrlKey = 'iptv_user_playlist_url';
  static const String _cacheKey = 'iptv_playlist_cache';
  static const String _cacheTimestampKey = 'iptv_playlist_timestamp';
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

    // Try cache first if not forcing refresh
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
    } catch (e) {
      print('[M3U] Failed to fetch user playlist: $e');
    }

    // Network failed; use only a cache derived from the user's own playlist.
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
    await _prefs.remove(_cacheKey);
    await _prefs.remove(_cacheTimestampKey);
  }

  /// Remove the configured playlist and its user-derived cache.
  Future<void> clearPlaylist() async {
    await _prefs.remove(_playlistUrlKey);
    await clearCache();
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

  /// Parse M3U content into channels with deduplication
  List<IPTVChannel> parseM3U(String content) {
    final lines = content.split('\n');
    final channels = <IPTVChannel>[];
    // Track seen channels by normalized name to deduplicate
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
        // Normalize the channel name for deduplication
        final normalizedName = _normalizeChannelName(currentName);

        // Create the channel
        final channel = IPTVChannel.fromM3U(
          name: _formatChannelName(currentName), // Use formatted name
          url: line,
          logo: currentLogo,
          group: currentGroup,
          tvgId: currentTvgId,
          tvgName: currentTvgName,
          language: currentLanguage,
        );

        // Deduplicate: keep the one with logo, or first occurrence
        if (!seenChannels.containsKey(normalizedName)) {
          seenChannels[normalizedName] = channel;
        } else {
          // Prefer channel with logo over one without
          final existing = seenChannels[normalizedName]!;
          if (existing.logoUrl == null && channel.logoUrl != null) {
            seenChannels[normalizedName] = channel;
          }
        }

        // Reset for next channel
        currentName = null;
        currentLogo = null;
        currentGroup = null;
        currentTvgId = null;
        currentTvgName = null;
        currentLanguage = null;
      }
    }

    // Return deduplicated channels
    channels.addAll(seenChannels.values);
    return channels;
  }

  /// Normalize channel name for deduplication (lowercase, remove special chars)
  String _normalizeChannelName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '') // Remove non-alphanumeric
        .replaceAll(RegExp(r'\s+'), ''); // Remove whitespace
  }

  /// Format channel name for display (proper capitalization)
  String _formatChannelName(String name) {
    // Remove extra whitespace
    name = name.trim().replaceAll(RegExp(r'\s+'), ' ');

    // Title case without correcting to specific channel brands.
    return name
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          // Keep acronyms uppercase (2-4 letter all-caps words)
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
        '#EXTINF:-1 tvg-logo="${ch.logoUrl ?? ""}" group-title="${ch.group}",${ch.name}',
      );
      buffer.writeln(ch.streamUrl);
    }
    await _prefs.setString(_cacheKey, buffer.toString());
    await _prefs.setInt(
      _cacheTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Clear cache
  Future<void> clearCache() async {
    await _prefs.remove(_cacheKey);
    await _prefs.remove(_cacheTimestampKey);
  }
}
