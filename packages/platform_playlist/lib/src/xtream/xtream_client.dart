import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

/// Result of Xtream Codes `player_api.php` auth (no `action` param).
class XtreamAuthResult extends Equatable {
  const XtreamAuthResult({required this.isAuthenticated, required this.status});

  final bool isAuthenticated;
  final String status;

  @override
  List<Object?> get props => [isAuthenticated, status];
}

class XtreamLiveStream extends Equatable {
  const XtreamLiveStream({
    required this.streamId,
    required this.name,
    this.streamIcon,
    this.categoryId,
    this.epgChannelId,
  });

  final int streamId;
  final String name;
  final String? streamIcon;
  final String? categoryId;
  final String? epgChannelId;

  @override
  List<Object?> get props => [streamId, name, streamIcon, categoryId, epgChannelId];
}

class XtreamVodStream extends Equatable {
  const XtreamVodStream({
    required this.streamId,
    required this.name,
    this.streamIcon,
    this.categoryId,
    this.containerExtension,
  });

  final int streamId;
  final String name;
  final String? streamIcon;
  final String? categoryId;
  final String? containerExtension;

  @override
  List<Object?> get props => [streamId, name, streamIcon, categoryId, containerExtension];
}

class XtreamEpgListing extends Equatable {
  const XtreamEpgListing({
    required this.id,
    required this.title,
    required this.description,
    required this.start,
    required this.end,
    required this.streamId,
  });

  final String id;
  final String title;
  final String description;
  final DateTime start;
  final DateTime end;
  final int streamId;

  @override
  List<Object?> get props => [id, title, description, start, end, streamId];
}

/// Xtream Codes `player_api.php` client. Wire protocol per the
/// widely-deployed Xtream Codes panel API (auth via query params, JSON
/// responses, base64-encoded EPG title/description).
///
/// Always builds full absolute URLs from [serverUrl] rather than relying on
/// the injected [Dio]'s `baseUrl` — the same convention
/// `M3UParserService._fetchAndParse` uses, since a single shared [Dio] may
/// serve multiple sources with different servers.
class XtreamClient {
  XtreamClient({
    required Dio dio,
    required String serverUrl,
    required String username,
    required String password,
  }) : _dio = dio,
       _serverUrl = serverUrl.endsWith('/')
           ? serverUrl.substring(0, serverUrl.length - 1)
           : serverUrl,
       _username = username,
       _password = password;

  final Dio _dio;
  final String _serverUrl;
  final String _username;
  final String _password;

  Map<String, dynamic> _baseParams([Map<String, dynamic>? extra]) => {
    'username': _username,
    'password': _password,
    ...?extra,
  };

  Future<XtreamAuthResult> authenticate() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_serverUrl/player_api.php',
      queryParameters: _baseParams(),
    );
    final userInfo = response.data?['user_info'] as Map<String, dynamic>?;
    final status = userInfo?['status'] as String? ?? 'Unknown';
    final auth = userInfo?['auth'];
    return XtreamAuthResult(
      isAuthenticated: auth == 1 || auth == '1',
      status: status,
    );
  }

  Future<List<XtreamLiveStream>> getLiveStreams() async {
    final response = await _dio.get<List<dynamic>>(
      '$_serverUrl/player_api.php',
      queryParameters: _baseParams({'action': 'get_live_streams'}),
    );
    return (response.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(
          (json) => XtreamLiveStream(
            streamId: json['stream_id'] as int,
            name: json['name'] as String,
            streamIcon: json['stream_icon'] as String?,
            categoryId: json['category_id'] as String?,
            epgChannelId: json['epg_channel_id'] as String?,
          ),
        )
        .toList();
  }

  Future<List<XtreamVodStream>> getVodStreams() async {
    final response = await _dio.get<List<dynamic>>(
      '$_serverUrl/player_api.php',
      queryParameters: _baseParams({'action': 'get_vod_streams'}),
    );
    return (response.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(
          (json) => XtreamVodStream(
            streamId: json['stream_id'] as int,
            name: json['name'] as String,
            streamIcon: json['stream_icon'] as String?,
            categoryId: json['category_id'] as String?,
            containerExtension: json['container_extension'] as String?,
          ),
        )
        .toList();
  }

  Future<List<XtreamEpgListing>> getShortEpg({
    required int streamId,
    int limit = 4,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_serverUrl/player_api.php',
      queryParameters: _baseParams({
        'action': 'get_short_epg',
        'stream_id': streamId,
        'limit': limit,
      }),
    );
    final listings = response.data?['epg_listings'] as List<dynamic>? ?? const [];
    return listings.cast<Map<String, dynamic>>().map((json) {
      return XtreamEpgListing(
        id: json['id'] as String,
        title: utf8.decode(base64.decode(json['title'] as String)),
        description: utf8.decode(base64.decode(json['description'] as String)),
        start: DateTime.parse((json['start'] as String).replaceFirst(' ', 'T')),
        end: DateTime.parse((json['end'] as String).replaceFirst(' ', 'T')),
        streamId: int.parse(json['stream_id'] as String),
      );
    }).toList();
  }

  String liveStreamUrl(int streamId, {String extension = 'm3u8'}) =>
      '$_serverUrl/live/$_username/$_password/$streamId.$extension';

  String vodStreamUrl(int streamId, String containerExtension) =>
      '$_serverUrl/movie/$_username/$_password/$streamId.$containerExtension';
}
