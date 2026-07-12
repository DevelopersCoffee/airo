import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/iptv_channel.dart';

/// Legacy channel-data service.
///
/// Play Store V2 uses a bring-your-own-content model. The app must not ship or
/// auto-fetch a first-party channel lineup, so this service intentionally
/// returns no channels. User-supplied M3U sources are handled by
/// `M3UParserService` in `platform_playlist_import`.
class ChannelDataService {
  static const String _cacheKey = 'iptv_channels_cache';
  static const String _versionKey = 'iptv_channels_version';
  static const String _cacheTimestampKey = 'iptv_channels_timestamp';

  final SharedPreferences _prefs;

  ChannelDataService({required Dio dio, required SharedPreferences prefs})
    : _prefs = prefs;

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
}
