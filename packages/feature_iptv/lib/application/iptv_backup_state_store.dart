import 'package:platform_channels/platform_channels.dart';
import 'package:platform_favorites/platform_favorites.dart';
import 'package:platform_playlist/platform_playlist.dart';
import 'package:platform_playlist_export/platform_playlist_export.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_source_store.dart';
import 'xmltv_source_store.dart';

abstract interface class IptvBackupSettingsStore {
  Future<Map<String, String>> read();

  Future<void> replace(Map<String, String> settings);
}

class SharedPreferencesIptvBackupSettingsStore
    implements IptvBackupSettingsStore {
  const SharedPreferencesIptvBackupSettingsStore(
    this.preferences, {
    this.recognizedKeys = defaultRecognizedKeys,
  });

  static const Set<String> defaultRecognizedKeys = {
    'caption_preference_enabled',
    'caption_preference_language',
    'video_aspect_ratio',
    'tv_font_mode',
    'airo_tv_picture_in_picture_enabled',
    'iptv_filter_search',
    'iptv_filter_category',
    'iptv_filter_country',
    'iptv_filter_language',
    'iptv_country_prompt_completed',
    'iptv_row_channel_visible',
    'iptv_row_stats_visible',
    'iptv_row_filter_visible',
    'iptv_row_hotbar_visible',
    'iptv_row_playlist_visible',
  };

  final SharedPreferences preferences;
  final Set<String> recognizedKeys;

  @override
  Future<Map<String, String>> read() async {
    final result = <String, String>{};
    for (final key in recognizedKeys) {
      final value = preferences.get(key);
      if (value is bool) result[key] = 'bool:$value';
      if (value is String) result[key] = 'string:$value';
      if (value is int) result[key] = 'int:$value';
      if (value is double) result[key] = 'double:$value';
    }
    return result;
  }

  @override
  Future<void> replace(Map<String, String> settings) async {
    if (settings.keys.any((key) => !recognizedKeys.contains(key))) {
      throw StateError('backup_setting_key_unrecognized');
    }
    for (final key in recognizedKeys) {
      await preferences.remove(key);
    }
    for (final entry in settings.entries) {
      final separator = entry.value.indexOf(':');
      if (separator <= 0) throw StateError('backup_setting_value_invalid');
      final type = entry.value.substring(0, separator);
      final value = entry.value.substring(separator + 1);
      final written = switch (type) {
        'bool' => preferences.setBool(entry.key, switch (value) {
          'true' => true,
          'false' => false,
          _ => throw StateError('backup_setting_value_invalid'),
        }),
        'string' => preferences.setString(entry.key, value),
        'int' => preferences.setInt(entry.key, int.parse(value)),
        'double' => preferences.setDouble(entry.key, double.parse(value)),
        _ => throw StateError('backup_setting_value_invalid'),
      };
      if (!await written) throw StateError('backup_setting_write_failed');
    }
  }
}

typedef FavoriteChannelResolver =
    Future<List<IPTVChannel>> Function(Set<String> channelIds);

class IptvBackupStateStore implements AiroBackupStateStore {
  const IptvBackupStateStore({
    required this.contentSources,
    required this.favorites,
    required this.xmltv,
    required this.settings,
    required this.resolveFavoriteChannels,
  });

  final ContentSourceStore contentSources;
  final FavoriteChannelsStorage favorites;
  final XmltvSourceStore xmltv;
  final IptvBackupSettingsStore settings;
  final FavoriteChannelResolver resolveFavoriteChannels;

  @override
  Future<AiroBackupSnapshot> read() async {
    final sourceRows = await contentSources.getAll();
    final favoriteIds = await favorites.getFavoriteChannelIds();
    final favoriteChannels = await resolveFavoriteChannels(favoriteIds);
    final resolvedIds = favoriteChannels.map((channel) => channel.id).toSet();
    if (!resolvedIds.containsAll(favoriteIds)) {
      throw StateError('backup_favorite_channel_unresolved');
    }
    final epg = await xmltv.load();
    return AiroBackupSnapshot(
      playlistSources: [
        for (final source in sourceRows)
          AiroBackupSource(
            id: source.id,
            url: source.url,
            label: source.label,
            metadata: {
              'kind': source.kind.stableId,
              if (source.macAddress != null) 'macAddress': source.macAddress!,
              if (source.kind == ContentSourceKind.xtream ||
                  source.kind == ContentSourceKind.jellyfin)
                'requiresReauthentication': 'true',
            },
          ),
      ],
      favorites: [
        for (final channel in favoriteChannels)
          AiroBackupFavorite(
            channelId: channel.id,
            name: channel.name,
            url: channel.streamUrl,
            group: channel.group,
          ),
      ],
      epgSources: [
        if (epg != null)
          AiroBackupSource(
            id: 'xmltv-primary',
            url: epg.url,
            label: 'XMLTV guide',
            metadata: {
              if (epg.lastRefreshedAt != null)
                'lastRefreshedAt': epg.lastRefreshedAt!
                    .toUtc()
                    .toIso8601String(),
              if (epg.lastError != null) 'lastError': epg.lastError!,
            },
          ),
      ],
      settings: await settings.read(),
    );
  }

  @override
  Future<void> replaceAtomically(AiroBackupSnapshot snapshot) async {
    if (snapshot.epgSources.length > 1) {
      throw StateError('backup_multiple_epg_sources_unsupported');
    }
    final previous = await read();
    try {
      await _replace(snapshot);
    } on Object {
      try {
        await _replace(previous);
      } on Object {
        throw StateError('backup_apply_and_rollback_failed');
      }
      rethrow;
    }
  }

  Future<void> _replace(AiroBackupSnapshot snapshot) async {
    final sourceConfigs = [
      for (final source in snapshot.playlistSources)
        ContentSourceConfig(
          id: source.id,
          kind: _contentSourceKind(source),
          label: source.label,
          url: source.url,
          macAddress: source.metadata['macAddress'],
        ),
    ];
    await contentSources.replaceAll(sourceConfigs);
    await favorites.replaceAll(
      snapshot.favorites.map((favorite) => favorite.channelId),
    );
    final epg = snapshot.epgSources.firstOrNull;
    if (epg == null) {
      await xmltv.clear();
    } else {
      await xmltv.save(
        XmltvSourceConfig(
          url: epg.url,
          lastRefreshedAt: DateTime.tryParse(
            epg.metadata['lastRefreshedAt'] ?? '',
          ),
          lastError: epg.metadata['lastError'],
        ),
      );
    }
    await settings.replace(snapshot.settings);
  }

  ContentSourceKind _contentSourceKind(AiroBackupSource source) {
    final stableId = source.metadata['kind'];
    if (stableId == null) return ContentSourceKind.m3u;
    for (final kind in ContentSourceKind.values) {
      if (kind.stableId == stableId) return kind;
    }
    throw StateError('backup_content_source_kind_unsupported');
  }
}
