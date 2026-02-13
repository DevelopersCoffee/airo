import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/iptv_channel.dart';

/// Service for fetching preprocessed channel data from IPTV Sanity Agent
class ChannelDataService {
  static const String _cacheKey = 'iptv_channels_cache';
  static const String _versionKey = 'iptv_channels_version';
  static const String _cacheTimestampKey = 'iptv_channels_timestamp';
  static const Duration _cacheValidity = Duration(hours: 3);

  /// GitHub Gist ID for IPTV channel data
  /// The Gist is updated daily by the IPTV Sanity Pipeline
  /// Gist URL: https://gist.github.com/ucguy4u/79b8648864da66d5aa2b6456d6c98fa3
  static const String _gistId = '79b8648864da66d5aa2b6456d6c98fa3';

  /// Primary URL: GitHub Gist (publicly accessible even if repo is private)
  static const String _dataUrl =
      'https://gist.githubusercontent.com/raw/$_gistId/iptv_channels.json';

  /// Fallback URL: Direct from repository (works if repo is public)
  static const String _fallbackDataUrl =
      'https://raw.githubusercontent.com/DevelopersCoffee/airo/main/iptv-data/output/current/iptv_channels.json';

  /// Fallback asset path for bundled channels
  static const String _fallbackAssetPath = 'assets/iptv_channels_fallback.json';

  final Dio _dio;
  final SharedPreferences _prefs;

  ChannelDataService({required Dio dio, required SharedPreferences prefs})
    : _dio = dio,
      _prefs = prefs;

  /// Fetch channels with caching and fallback support
  Future<List<IPTVChannel>> fetchChannels({bool forceRefresh = false}) async {
    // Try cache first if not forcing refresh
    if (!forceRefresh) {
      final cached = await _loadFromCache();
      if (cached != null && cached.isNotEmpty) {
        // Check if we should refresh in background
        _maybeRefreshInBackground();
        return cached;
      }
    }

    // Try fetching from remote
    try {
      final channels = await _fetchFromRemote();
      if (channels.isNotEmpty) {
        await _saveToCache(channels);
        return channels;
      }
    } catch (e) {
      print('[ChannelDataService] Failed to fetch from remote: $e');
    }

    // Try cache as fallback (even if expired)
    final cached = await _loadFromCache(ignoreExpiry: true);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    // Last resort: bundled asset
    try {
      return await _loadFromAsset();
    } catch (e) {
      print('[ChannelDataService] Failed to load fallback asset: $e');
      throw Exception('Failed to load channels from all sources');
    }
  }

  /// Fetch channels from remote URL with fallback
  Future<List<IPTVChannel>> _fetchFromRemote() async {
    // Try primary URL (Gist) first, then fallback to repo URL
    final urls = [_dataUrl, _fallbackDataUrl];

    for (final url in urls) {
      try {
        final response = await _dio.get<String>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

        if (response.data != null && response.data!.isNotEmpty) {
          return _parseChannelsJson(response.data!);
        }
      } catch (e) {
        print('[ChannelDataService] Failed to fetch from $url: $e');
        // Continue to next URL
      }
    }

    throw Exception('Failed to fetch from all remote URLs');
  }

  /// Parse channels from JSON string
  List<IPTVChannel> _parseChannelsJson(String jsonStr) {
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final channelsList = data['channels'] as List<dynamic>? ?? [];

    return channelsList
        .map((ch) => IPTVChannel.fromJson(ch as Map<String, dynamic>))
        .toList();
  }

  /// Load channels from cache
  Future<List<IPTVChannel>?> _loadFromCache({bool ignoreExpiry = false}) async {
    if (!ignoreExpiry) {
      final timestamp = _prefs.getInt(_cacheTimestampKey);
      if (timestamp == null) return null;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheTime) > _cacheValidity) {
        return null; // Cache expired
      }
    }

    final cached = _prefs.getString(_cacheKey);
    if (cached == null) return null;

    try {
      return _parseChannelsJson(cached);
    } catch (e) {
      print('[ChannelDataService] Failed to parse cached data: $e');
      return null;
    }
  }

  /// Save channels to cache
  Future<void> _saveToCache(List<IPTVChannel> channels) async {
    final data = {'channels': channels.map((ch) => ch.toJson()).toList()};
    await _prefs.setString(_cacheKey, json.encode(data));
    await _prefs.setInt(
      _cacheTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Load channels from bundled asset
  Future<List<IPTVChannel>> _loadFromAsset() async {
    final jsonStr = await rootBundle.loadString(_fallbackAssetPath);
    return _parseChannelsJson(jsonStr);
  }

  /// Maybe refresh in background if cache is getting stale
  void _maybeRefreshInBackground() {
    final timestamp = _prefs.getInt(_cacheTimestampKey);
    if (timestamp == null) return;

    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final staleDuration = _cacheValidity ~/ 2; // Refresh after half validity

    if (DateTime.now().difference(cacheTime) > staleDuration) {
      // Refresh in background (fire and forget)
      _fetchFromRemote()
          .then((channels) {
            if (channels.isNotEmpty) {
              _saveToCache(channels);
            }
          })
          .catchError((e) {
            print('[ChannelDataService] Background refresh failed: $e');
          });
    }
  }

  /// Clear cache
  Future<void> clearCache() async {
    await _prefs.remove(_cacheKey);
    await _prefs.remove(_versionKey);
    await _prefs.remove(_cacheTimestampKey);
  }

  /// Get current cache version
  String? getCacheVersion() => _prefs.getString(_versionKey);
}
