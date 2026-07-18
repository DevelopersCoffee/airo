import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../provider_health.dart';
import '../provider_health_recorder.dart';

class StalkerChannel extends Equatable {
  const StalkerChannel({
    required this.id,
    required this.name,
    required this.cmd,
    this.number,
    this.logo,
    this.genreId,
  });

  final String id;
  final String name;
  final String cmd;
  final String? number;
  final String? logo;
  final String? genreId;

  @override
  List<Object?> get props => [id, name, cmd, number, logo, genreId];
}

/// Stalker Portal (Ministra middleware) client.
///
/// Auth is MAC-address based: the device MAC goes in a `Cookie: mac=...`
/// header on every request, `handshake` exchanges it for a short-lived
/// session token, and channel URLs must be resolved per-play via
/// `create_link` — the `cmd` field from `get_ordered_list` is not itself
/// playable.
///
/// Always builds full absolute URLs from [serverUrl] rather than relying on
/// the injected [Dio]'s `baseUrl` — same convention as `XtreamClient` and
/// `M3UParserService._fetchAndParse`, since a single shared [Dio] may serve
/// multiple sources with different servers.
class StalkerClient {
  StalkerClient({
    required Dio dio,
    required String serverUrl,
    required String macAddress,
    ProviderHealthTracker? healthTracker,
    String? sourceId,
  }) : _dio = dio,
       _serverUrl = serverUrl.endsWith('/')
           ? serverUrl.substring(0, serverUrl.length - 1)
           : serverUrl,
       _macAddress = macAddress,
       _healthTracker = healthTracker,
       _sourceId = sourceId;

  final Dio _dio;
  final String _serverUrl;
  final String _macAddress;
  final ProviderHealthTracker? _healthTracker;
  final String? _sourceId;

  Future<T> _recorded<T>(Future<T> Function() body) =>
      recordFetch<T>(body: body, tracker: _healthTracker, sourceId: _sourceId);

  Map<String, String> get _macHeaders => {
    'Cookie': 'mac=$_macAddress; stb_lang=en; timezone=UTC',
  };

  Future<String> handshake() => _recorded(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_serverUrl/portal.php',
      queryParameters: {
        'type': 'stb',
        'action': 'handshake',
        'token': '',
        'JsHttpRequest': '1-xml',
      },
      options: Options(headers: _macHeaders),
    );
    return response.data?['js']?['token'] as String;
  });

  Future<List<StalkerChannel>> getChannels({required String token}) =>
      _recorded(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '$_serverUrl/portal.php',
          queryParameters: {
            'type': 'itv',
            'action': 'get_ordered_list',
            'genre': '*',
            'JsHttpRequest': '1-xml',
          },
          options: Options(
            headers: {..._macHeaders, 'Authorization': 'Bearer $token'},
          ),
        );
        final data =
            response.data?['js']?['data'] as List<dynamic>? ?? const [];
        return data.cast<Map<String, dynamic>>().map((json) {
          return StalkerChannel(
            id: json['id'] as String,
            name: json['name'] as String,
            cmd: json['cmd'] as String,
            number: json['number'] as String?,
            logo: json['logo'] as String?,
            genreId: json['tv_genre_id'] as String?,
          );
        }).toList();
      });

  Future<String> createLink({required String token, required String cmd}) =>
      _recorded(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '$_serverUrl/portal.php',
          queryParameters: {
            'type': 'itv',
            'action': 'create_link',
            'cmd': cmd,
            'JsHttpRequest': '1-xml',
          },
          options: Options(
            headers: {..._macHeaders, 'Authorization': 'Bearer $token'},
          ),
        );
        return response.data?['js']?['cmd'] as String;
      });
}
