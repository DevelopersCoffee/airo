import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/channel_filters_provider.dart';
import 'providers/iptv_providers.dart' show dioProvider, iptvChannelsProvider;

const _channelsUrl = 'https://iptv-org.github.io/api/channels.json';
const _feedsUrl = 'https://iptv-org.github.io/api/feeds.json';
const _streamsUrl = 'https://iptv-org.github.io/api/streams.json';

/// Fetches public metadata only. Parsing happens off the UI isolate; failure
/// deliberately yields no extra metadata rather than blocking playlist browse.
final channelBrowseMetadataProvider =
    FutureProvider<Map<String, ChannelBrowseMetadata>>((ref) async {
      try {
        final dio = ref.watch(dioProvider);
        final responses = await Future.wait([
          dio.get<String>(
            _channelsUrl,
            options: Options(responseType: ResponseType.plain),
          ),
          dio.get<String>(
            _feedsUrl,
            options: Options(responseType: ResponseType.plain),
          ),
          dio.get<String>(
            _streamsUrl,
            options: Options(responseType: ResponseType.plain),
          ),
        ]);
        final channels = await ref.watch(iptvChannelsProvider.future);
        return compute(_matchMetadata, <Object?>[
          channels
              .map(
                (channel) => <String, String?>{
                  'id': channel.id,
                  'streamUrl': channel.streamUrl,
                  'tvgName': channel.tvgName,
                },
              )
              .toList(),
          responses.map((response) => response.data ?? '[]').toList(),
        ]);
      } catch (_) {
        return const {};
      }
    });

Map<String, ChannelBrowseMetadata> _matchMetadata(List<Object?> input) {
  final playlists = (input[0] as List).cast<Map<String, String?>>();
  final payloads = (input[1] as List).cast<String>();
  final channels = (jsonDecode(payloads[0]) as List)
      .cast<Map<String, dynamic>>();
  final feeds = (jsonDecode(payloads[1]) as List).cast<Map<String, dynamic>>();
  final streams = (jsonDecode(payloads[2]) as List)
      .cast<Map<String, dynamic>>();
  final byId = {for (final item in channels) item['id'] as String: item};
  final streamChannel = {
    for (final item in streams)
      if (item['url'] is String && item['channel'] is String)
        item['url'] as String: item['channel'] as String,
  };
  final languageByChannel = <String, String>{};
  for (final item in feeds) {
    final id = item['channel'];
    final languages = item['languages'];
    if (id is String &&
        languages is List &&
        languages.isNotEmpty &&
        languages.first is String) {
      languageByChannel.putIfAbsent(id, () => languages.first as String);
    }
  }
  final result = <String, ChannelBrowseMetadata>{};
  for (final playlist in playlists) {
    final sourceId =
        streamChannel[playlist['streamUrl']] ??
        playlist['tvgName'] ??
        playlist['id'];
    final record = sourceId == null ? null : byId[sourceId];
    if (record == null) continue;
    final country = record['country'] as String?;
    final language = languageByChannel[sourceId];
    if (country != null || language != null) {
      result[playlist['id']!] = ChannelBrowseMetadata(
        country: country,
        language: language,
      );
    }
  }
  return result;
}
