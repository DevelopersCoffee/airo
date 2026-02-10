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

    // Known channel name mappings for consistency
    const nameCorrections = {
      'b4u music': 'B4U Music',
      'b4u beats': 'B4U Beats',
      '9xm': '9XM',
      '9x jalwa': '9X Jalwa',
      'mtv': 'MTV',
      'vh1': 'VH1',
      'ndtv': 'NDTV',
      'ndtv india': 'NDTV India',
      'aaj tak': 'Aaj Tak',
      'zee news': 'Zee News',
      'republic tv': 'Republic TV',
      'times now': 'Times Now',
      'india today': 'India Today',
      'cnn': 'CNN',
      'bbc': 'BBC',
      'star plus': 'Star Plus',
      'star gold': 'Star Gold',
      'sony tv': 'Sony TV',
      'colors': 'Colors',
      'zee tv': 'Zee TV',
      'discovery': 'Discovery',
      'nat geo': 'Nat Geo',
      'national geographic': 'National Geographic',
      'cartoon network': 'Cartoon Network',
      'pogo': 'Pogo',
      'nick': 'Nick',
      'disney': 'Disney',
    };

    final lowerName = name.toLowerCase();

    // Check for known corrections
    for (final entry in nameCorrections.entries) {
      if (lowerName == entry.key || lowerName.contains(entry.key)) {
        // If exact match, return the correction
        if (lowerName == entry.key) return entry.value;
        // If partial match, replace the part
        return name.replaceAll(
          RegExp(entry.key, caseSensitive: false),
          entry.value,
        );
      }
    }

    // Default: Title Case
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
