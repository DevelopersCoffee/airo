import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

class JellyfinAuthResult extends Equatable {
  const JellyfinAuthResult({required this.accessToken, required this.userId});

  final String accessToken;
  final String userId;

  @override
  List<Object?> get props => [accessToken, userId];

  @override
  String toString() =>
      'JellyfinAuthResult(userId: $userId, accessToken: redacted)';
}

class JellyfinChannel extends Equatable {
  const JellyfinChannel({required this.id, required this.name, this.number});

  final String id;
  final String name;
  final String? number;

  @override
  List<Object?> get props => [id, name, number];
}

class JellyfinProgram extends Equatable {
  const JellyfinProgram({
    required this.id,
    required this.name,
    required this.channelId,
    required this.startDate,
    required this.endDate,
    this.overview,
  });

  final String id;
  final String name;
  final String channelId;
  final DateTime startDate;
  final DateTime endDate;
  final String? overview;

  @override
  List<Object?> get props => [
    id,
    name,
    channelId,
    startDate,
    endDate,
    overview,
  ];
}

/// Jellyfin Media Server client — official REST API
/// (`/Users/AuthenticateByName`, `/LiveTv/Channels`, `/LiveTv/Programs`).
///
/// Always builds full absolute URLs from [serverUrl] rather than relying on
/// the injected [Dio]'s `baseUrl` — same convention as `XtreamClient` and
/// `StalkerClient`, since a single shared [Dio] may serve multiple sources
/// with different servers.
class JellyfinClient {
  JellyfinClient({
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

  static const String _authHeader =
      'MediaBrowser Client="Airo TV", Device="Airo TV Client", '
      'DeviceId="airo-tv", Version="2.0.0"';

  Future<JellyfinAuthResult> authenticate() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_serverUrl/Users/AuthenticateByName',
      data: {'Username': _username, 'Pw': _password},
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'X-Emby-Authorization': _authHeader,
        },
      ),
    );
    final data = response.data ?? const {};
    return JellyfinAuthResult(
      accessToken: data['AccessToken'] as String,
      userId: (data['User'] as Map<String, dynamic>)['Id'] as String,
    );
  }

  Future<List<JellyfinChannel>> getLiveTvChannels({
    required String accessToken,
    required String userId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_serverUrl/LiveTv/Channels',
      queryParameters: {'userId': userId, 'api_key': accessToken},
    );
    final items = response.data?['Items'] as List<dynamic>? ?? const [];
    return items.cast<Map<String, dynamic>>().map((json) {
      return JellyfinChannel(
        id: json['Id'] as String,
        name: json['Name'] as String,
        number: json['Number'] as String?,
      );
    }).toList();
  }

  Future<List<JellyfinProgram>> getPrograms({
    required String accessToken,
    required String userId,
    required List<String> channelIds,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_serverUrl/LiveTv/Programs',
      queryParameters: {
        'ChannelIds': channelIds.join(','),
        'UserId': userId,
        'api_key': accessToken,
      },
    );
    final items = response.data?['Items'] as List<dynamic>? ?? const [];
    return items.cast<Map<String, dynamic>>().map((json) {
      return JellyfinProgram(
        id: json['Id'] as String,
        name: json['Name'] as String,
        channelId: json['ChannelId'] as String,
        startDate: DateTime.parse(json['StartDate'] as String),
        endDate: DateTime.parse(json['EndDate'] as String),
        overview: json['Overview'] as String?,
      );
    }).toList();
  }

  String streamUrl(String itemId, String accessToken) =>
      '$_serverUrl/Videos/$itemId/stream?api_key=$accessToken&static=true';
}
